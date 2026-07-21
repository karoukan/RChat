defmodule RChat.Communities.Permissions do
  @moduledoc """
  Community level permissions stored as an integer bitfield on roles.

  A member's effective permissions are the OR of all their roles plus the
  community default role. The `:administrator` bit grants every permission.
  The community owner bypasses permission checks entirely, including
  `:administrator`; that bypass is enforced by the callers, not here.

  Role hierarchy uses the role `position` field, higher wins: a member may
  only act on roles strictly below their own highest role.
  """

  import Bitwise

  @bits %{
    administrator: 1 <<< 0,
    manage_community: 1 <<< 1,
    manage_channels: 1 <<< 2,
    manage_roles: 1 <<< 3,
    manage_messages: 1 <<< 4,
    kick_members: 1 <<< 5,
    ban_members: 1 <<< 6,
    create_invites: 1 <<< 7,
    send_messages: 1 <<< 8
  }

  @type permission :: unquote(Enum.reduce(Map.keys(@bits), &{:|, [], [&1, &2]}))

  def all, do: Map.keys(@bits)

  def bit(permission), do: Map.fetch!(@bits, permission)

  @doc """
  Combines a list of permission names into a bitfield.
  """
  def combine(permissions) do
    Enum.reduce(permissions, 0, &(bit(&1) ||| &2))
  end

  @doc """
  Combines the bitfields of several roles into effective permissions.
  """
  def resolve(bitfields) when is_list(bitfields) do
    Enum.reduce(bitfields, 0, &|||/2)
  end

  @doc """
  Checks a permission against a bitfield. The `:administrator` bit
  grants everything.
  """
  def has?(bitfield, permission) when is_integer(bitfield) do
    admin?(bitfield) or (bitfield &&& bit(permission)) != 0
  end

  def admin?(bitfield) when is_integer(bitfield) do
    (bitfield &&& bit(:administrator)) != 0
  end

  @doc """
  Bitfield granted to the default role of a new community.
  """
  def default do
    combine([:send_messages, :create_invites])
  end

  @doc """
  Hierarchy rule: acting on a role requires a strictly higher position.
  """
  def can_act_on?(actor_position, target_position)
      when is_integer(actor_position) and is_integer(target_position) do
    actor_position > target_position
  end

  @doc """
  Highest role position of a member, 0 when they have no role.
  """
  def top_position(roles) do
    roles |> Enum.map(& &1.position) |> Enum.max(fn -> 0 end)
  end
end
