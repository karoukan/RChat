defmodule RChat.CommunitiesTest do
  use RChat.DataCase

  alias RChat.Communities
  alias RChat.Communities.{Membership, Role}

  import RChat.AccountsFixtures
  import RChat.CommunitiesFixtures

  describe "create_community/2" do
    setup do
      %{scope: user_scope_fixture()}
    end

    test "creates the community with a slug", %{scope: scope} do
      {:ok, community} = Communities.create_community(scope, %{name: "Guilde des Brasseurs"})

      assert community.name == "Guilde des Brasseurs"
      assert community.slug == "guilde-des-brasseurs"
      assert community.owner_id == scope.user.id
    end

    test "creates the default role, the general channel and the owner membership", %{
      scope: scope
    } do
      {:ok, community} = Communities.create_community(scope, %{name: "test"})

      assert [role] = Repo.all_by(Role, community_id: community.id)
      assert role.is_default
      assert role.name == "member"
      assert role.permissions == Communities.Permissions.default()

      assert [channel] = Communities.list_channels(community)
      assert channel.name == "general"

      assert Repo.get_by(Membership, user_id: scope.user.id, community_id: community.id)
    end

    test "validates the name", %{scope: scope} do
      {:error, changeset} = Communities.create_community(scope, %{name: "x"})
      assert "should be at least 2 character(s)" in errors_on(changeset).name

      {:error, changeset} = Communities.create_community(scope, %{name: nil})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "rejects a taken slug and rolls everything back", %{scope: scope} do
      {:ok, _} = Communities.create_community(scope, %{name: "My Guild"})
      {:error, changeset} = Communities.create_community(scope, %{name: "my guild"})

      assert "has already been taken" in errors_on(changeset).slug
      assert length(Communities.list_communities(scope)) == 1
    end
  end

  describe "list_communities/1 and get_community!/2" do
    test "only returns communities the user belongs to" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()

      mine = community_fixture(scope)
      _theirs = community_fixture(other_scope)

      assert [community] = Communities.list_communities(scope)
      assert community.id == mine.id
    end

    test "get_community!/2 raises for non members" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      community = community_fixture(other_scope)

      assert_raise Ecto.NoResultsError, fn ->
        Communities.get_community!(scope, community.slug)
      end
    end

    test "get_community!/2 returns the community for members" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      community = community_fixture(other_scope)
      join_community(scope.user, community)

      assert Communities.get_community!(scope, community.slug).id == community.id
    end
  end

  describe "channels" do
    setup do
      scope = user_scope_fixture()
      %{scope: scope, community: community_fixture(scope)}
    end

    test "create_channel/3 allows the owner", %{scope: scope, community: community} do
      {:ok, channel} = Communities.create_channel(scope, community, %{name: "random"})

      assert channel.community_id == community.id
      assert Enum.map(Communities.list_channels(community), & &1.name) == ["general", "random"]
    end

    test "create_channel/3 rejects members without manage_channels", %{community: community} do
      member_scope = user_scope_fixture()
      join_community(member_scope.user, community)

      assert {:error, :unauthorized} =
               Communities.create_channel(member_scope, community, %{name: "random"})
    end

    test "create_channel/3 validates the name", %{scope: scope, community: community} do
      {:error, changeset} = Communities.create_channel(scope, community, %{name: "Not Valid"})
      assert "only lowercase letters, numbers and dashes" in errors_on(changeset).name
    end

    test "channel names are unique per community", %{scope: scope, community: community} do
      {:error, changeset} = Communities.create_channel(scope, community, %{name: "general"})
      assert "has already been taken" in errors_on(changeset).name
    end

    test "get_channel!/2 scopes by community", %{scope: scope, community: community} do
      other_community = community_fixture(scope, %{name: "other"})
      [channel] = Communities.list_channels(community)

      assert_raise Ecto.NoResultsError, fn ->
        Communities.get_channel!(other_community, channel.id)
      end
    end
  end

  describe "permitted?/3" do
    setup do
      owner_scope = user_scope_fixture()
      community = community_fixture(owner_scope)
      member_scope = user_scope_fixture()
      join_community(member_scope.user, community)

      %{owner_scope: owner_scope, member_scope: member_scope, community: community}
    end

    test "the owner can do everything", %{owner_scope: scope, community: community} do
      assert Communities.permitted?(scope, community, :manage_community)
      assert Communities.permitted?(scope, community, :manage_channels)
    end

    test "members get the default role permissions", %{
      member_scope: scope,
      community: community
    } do
      assert Communities.permitted?(scope, community, :send_messages)
      assert Communities.permitted?(scope, community, :create_invites)
      refute Communities.permitted?(scope, community, :manage_channels)
      refute Communities.permitted?(scope, community, :kick_members)
    end

    test "non members have no permission", %{community: community} do
      stranger = user_scope_fixture()

      refute Communities.permitted?(stranger, community, :send_messages)
    end

    test "an extra role extends the default permissions", %{
      member_scope: scope,
      community: community
    } do
      alias RChat.Communities.Permissions

      role =
        Repo.insert!(%Role{
          community_id: community.id,
          name: "moderator",
          permissions: Permissions.combine([:kick_members, :manage_messages]),
          position: 1
        })

      membership = Communities.get_membership(scope, community)
      Repo.insert_all("membership_roles", [[membership_id: membership.id, role_id: role.id]])

      assert Communities.permitted?(scope, community, :kick_members)
      assert Communities.permitted?(scope, community, :send_messages)
      refute Communities.permitted?(scope, community, :manage_roles)
    end
  end
end
