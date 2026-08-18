defmodule RChat.ChatTest do
  use RChat.DataCase

  alias RChat.Chat
  alias RChat.Chat.Message
  alias RChat.Communities

  import RChat.AccountsFixtures
  import RChat.ChatFixtures
  import RChat.CommunitiesFixtures

  setup do
    scope = user_scope_fixture()
    community = community_fixture(scope)
    [channel] = Communities.list_channels(community)

    %{scope: scope, community: community, channel: channel}
  end

  describe "create_message/4" do
    test "persists the message with its author", %{
      scope: scope,
      community: community,
      channel: channel
    } do
      {:ok, message} = Chat.create_message(scope, community, channel, %{content: "hello"})

      assert message.content == "hello"
      assert message.channel_id == channel.id
      assert message.author.id == scope.user.id
      assert Repo.get!(Message, message.id)
    end

    test "broadcasts to community subscribers", %{
      scope: scope,
      community: community,
      channel: channel
    } do
      Chat.subscribe_community(community)

      {:ok, message} = Chat.create_message(scope, community, channel, %{content: "hello"})

      assert_receive {:message_created, ^message}
      assert message.channel.id == channel.id
    end

    test "validates the content", %{scope: scope, community: community, channel: channel} do
      {:error, changeset} = Chat.create_message(scope, community, channel, %{content: ""})
      assert "can't be blank" in errors_on(changeset).content

      too_long = String.duplicate("a", 4001)
      {:error, changeset} = Chat.create_message(scope, community, channel, %{content: too_long})
      assert "should be at most 4000 character(s)" in errors_on(changeset).content
    end

    test "rejects non members", %{community: community, channel: channel} do
      stranger = user_scope_fixture()

      assert {:error, :unauthorized} =
               Chat.create_message(stranger, community, channel, %{content: "hello"})
    end

    test "raises when the channel does not belong to the community", %{
      scope: scope,
      community: community
    } do
      other = community_fixture(scope, %{name: "other"})
      [other_channel] = Communities.list_channels(other)

      assert_raise MatchError, fn ->
        Chat.create_message(scope, community, other_channel, %{content: "hello"})
      end
    end
  end

  describe "read states" do
    test "mark_channel_read/2 and first_unread_id/2", %{
      scope: scope,
      community: community,
      channel: channel
    } do
      reader = user_scope_fixture()
      join_community(reader.user, community)

      first = message_fixture(scope, community, channel)
      assert Chat.first_unread_id(reader, channel) == first.id

      Chat.mark_channel_read(reader, channel)
      assert Chat.first_unread_id(reader, channel) == nil

      second = message_fixture(scope, community, channel)
      assert Chat.first_unread_id(reader, channel) == second.id
    end

    test "unread_channel_ids/2 and unread_community_ids/1", %{
      scope: scope,
      community: community,
      channel: channel
    } do
      reader = user_scope_fixture()
      join_community(reader.user, community)

      assert Chat.unread_channel_ids(reader, community) == MapSet.new()
      assert Chat.unread_community_ids(reader) == MapSet.new()

      message_fixture(scope, community, channel)

      assert Chat.unread_channel_ids(reader, community) == MapSet.new([channel.id])
      assert Chat.unread_community_ids(reader) == MapSet.new([community.id])

      Chat.mark_channel_read(reader, channel)

      assert Chat.unread_channel_ids(reader, community) == MapSet.new()
      assert Chat.unread_community_ids(reader) == MapSet.new()
    end
  end

  describe "list_messages/2" do
    test "returns messages in chronological order", %{
      scope: scope,
      community: community,
      channel: channel
    } do
      first = message_fixture(scope, community, channel)
      second = message_fixture(scope, community, channel)

      assert [%{id: id1}, %{id: id2}] = Chat.list_messages(channel)
      assert id1 == first.id
      assert id2 == second.id
    end

    test "preloads authors", %{scope: scope, community: community, channel: channel} do
      message_fixture(scope, community, channel)

      assert [message] = Chat.list_messages(channel)
      assert message.author.username == scope.user.username
    end

    test "respects the limit and keeps the most recent messages", %{
      scope: scope,
      community: community,
      channel: channel
    } do
      _first = message_fixture(scope, community, channel)
      second = message_fixture(scope, community, channel)
      third = message_fixture(scope, community, channel)

      assert [%{id: id1}, %{id: id2}] = Chat.list_messages(channel, limit: 2)
      assert id1 == second.id
      assert id2 == third.id
    end

    test "paginates upward with :before", %{
      scope: scope,
      community: community,
      channel: channel
    } do
      first = message_fixture(scope, community, channel)
      second = message_fixture(scope, community, channel)
      third = message_fixture(scope, community, channel)

      assert [%{id: id1}, %{id: id2}] = Chat.list_messages(channel, before: third.id, limit: 2)
      assert id1 == first.id
      assert id2 == second.id

      assert [%{id: ^id1}] = Chat.list_messages(channel, before: second.id, limit: 2)
      assert Chat.list_messages(channel, before: first.id, limit: 2) == []
    end

    test "excludes soft deleted messages", %{
      scope: scope,
      community: community,
      channel: channel
    } do
      message = message_fixture(scope, community, channel)
      kept = message_fixture(scope, community, channel)

      Repo.update_all(
        from(m in Message, where: m.id == ^message.id),
        set: [deleted_at: DateTime.utc_now()]
      )

      assert [%{id: id}] = Chat.list_messages(channel)
      assert id == kept.id
    end
  end
end
