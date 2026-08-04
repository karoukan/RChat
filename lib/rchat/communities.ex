defmodule RChat.Communities do
  @moduledoc """
  The Communities context: communities, channels, memberships, roles
  and invites.

  Every read is scoped by the caller's membership. Functions taking a
  `%Scope{}` never return data from communities the user does not
  belong to.
  """

  import Ecto.Query, warn: false

  alias RChat.Accounts.Scope
  alias RChat.Communities.{Channel, Community, Invite, Membership, Permissions, Role}
  alias RChat.Repo

  ## Communities

  def list_communities(%Scope{user: user}) do
    from(c in Community,
      join: m in Membership,
      on: m.community_id == c.id,
      where: m.user_id == ^user.id,
      order_by: c.name
    )
    |> Repo.all()
  end

  def get_community!(%Scope{user: user}, slug) when is_binary(slug) do
    from(c in Community,
      join: m in Membership,
      on: m.community_id == c.id,
      where: m.user_id == ^user.id and c.slug == ^slug
    )
    |> Repo.one!()
  end

  def change_community(%Community{} = community, attrs \\ %{}) do
    Community.changeset(community, attrs)
  end

  @doc """
  Creates a community owned by the scope's user, along with its default
  role, a #general channel and the owner's membership.
  """
  def create_community(%Scope{user: user}, attrs) do
    changeset = Community.changeset(%Community{owner_id: user.id}, attrs)

    Repo.transact(fn ->
      with {:ok, community} <- Repo.insert(changeset),
           {:ok, _role} <- insert_default_role(community),
           {:ok, _channel} <- insert_channel(community, %{name: "general"}),
           {:ok, _membership} <- insert_membership(user, community) do
        {:ok, community}
      end
    end)
  end

  defp insert_default_role(community) do
    %Role{
      community_id: community.id,
      name: "member",
      permissions: Permissions.default(),
      is_default: true
    }
    |> Repo.insert()
  end

  defp insert_membership(user, community) do
    Repo.insert(%Membership{user_id: user.id, community_id: community.id})
  end

  ## Channels

  def list_channels(%Community{} = community) do
    from(ch in Channel,
      where: ch.community_id == ^community.id,
      order_by: [ch.position, ch.id]
    )
    |> Repo.all()
  end

  def get_channel!(%Community{} = community, id) do
    Repo.get_by!(Channel, id: id, community_id: community.id)
  end

  def change_channel(%Channel{} = channel, attrs \\ %{}) do
    Channel.changeset(channel, attrs)
  end

  def create_channel(%Scope{} = scope, %Community{} = community, attrs) do
    if permitted?(scope, community, :manage_channels) do
      insert_channel(community, attrs)
    else
      {:error, :unauthorized}
    end
  end

  defp insert_channel(community, attrs) do
    %Channel{community_id: community.id}
    |> Channel.changeset(attrs)
    |> Repo.insert()
  end

  ## Members

  def list_members(%Community{} = community) do
    from(m in Membership,
      where: m.community_id == ^community.id,
      join: u in assoc(m, :user),
      preload: [user: u],
      order_by: u.username
    )
    |> Repo.all()
  end

  def get_membership(%Scope{user: user}, %Community{} = community) do
    Repo.get_by(Membership, user_id: user.id, community_id: community.id)
  end

  ## Invites

  def create_invite(%Scope{user: user} = scope, %Community{} = community, attrs \\ %{}) do
    if permitted?(scope, community, :create_invites) do
      %Invite{community_id: community.id, created_by_id: user.id}
      |> Invite.changeset(attrs)
      |> Repo.insert()
    else
      {:error, :unauthorized}
    end
  end

  def list_active_invites(%Scope{} = scope, %Community{} = community) do
    if permitted?(scope, community, :create_invites) do
      now = DateTime.utc_now()

      from(i in Invite,
        where: i.community_id == ^community.id,
        where: is_nil(i.expires_at) or i.expires_at > ^now,
        where: is_nil(i.max_uses) or i.uses < i.max_uses,
        order_by: [desc: i.id]
      )
      |> Repo.all()
    else
      []
    end
  end

  def get_invite_by_code(code) when is_binary(code) do
    Invite
    |> Repo.get_by(code: code)
    |> Repo.preload(:community)
  end

  def invite_status(%Invite{} = invite) do
    cond do
      invite.expires_at && DateTime.after?(DateTime.utc_now(), invite.expires_at) -> :expired
      invite.max_uses && invite.uses >= invite.max_uses -> :exhausted
      true -> :valid
    end
  end

  @doc """
  The single entry point to join a community through an invite code.

  Creates the membership and burns one invite use atomically. Every
  membership created from an invite goes through here.
  """
  def accept_invite(%Scope{user: user}, code) when is_binary(code) do
    # TODO: reject banned users here once bans land
    Repo.transact(fn ->
      case get_invite_by_code(code) do
        nil ->
          {:error, :not_found}

        %Invite{} = invite ->
          cond do
            invite_status(invite) == :expired ->
              {:error, :expired}

            Repo.get_by(Membership, user_id: user.id, community_id: invite.community_id) ->
              {:error, :already_member}

            true ->
              claim_invite_use(user, invite)
          end
      end
    end)
  end

  defp claim_invite_use(user, invite) do
    claimed =
      from(i in Invite,
        where: i.id == ^invite.id,
        where: is_nil(i.max_uses) or i.uses < i.max_uses
      )
      |> Repo.update_all(inc: [uses: 1])

    case claimed do
      {1, _} ->
        with {:ok, _membership} <- insert_membership(user, invite.community) do
          {:ok, invite.community}
        end

      {0, _} ->
        {:error, :exhausted}
    end
  end

  def count_members(%Community{} = community) do
    from(m in Membership, where: m.community_id == ^community.id)
    |> Repo.aggregate(:count)
  end

  ## Permissions

  @doc """
  Checks a community permission for the scope's user. The owner bypasses
  everything, then the bitfields of the member's roles plus the default
  role apply.
  """
  def permitted?(%Scope{user: user} = scope, %Community{} = community, permission) do
    cond do
      community.owner_id == user.id ->
        true

      membership = get_membership(scope, community) ->
        membership
        |> effective_permissions(community)
        |> Permissions.has?(permission)

      true ->
        false
    end
  end

  defp effective_permissions(membership, community) do
    role_bits =
      from(r in Role,
        join: mr in "membership_roles",
        on: mr.role_id == r.id,
        where: mr.membership_id == ^membership.id,
        select: r.permissions
      )
      |> Repo.all()

    default_bits =
      from(r in Role,
        where: r.community_id == ^community.id and r.is_default,
        select: r.permissions
      )
      |> Repo.all()

    Permissions.resolve(role_bits ++ default_bits)
  end
end
