defmodule RChat.Chat do
  @moduledoc """
  The Chat context: messages and read states.

  Writes are checked against the caller's membership and permissions,
  reads expect a channel that was already fetched through a scoped
  `RChat.Communities` function.
  """

  import Ecto.Query, warn: false

  alias RChat.Accounts.Scope
  alias RChat.Chat.{ChannelReadState, Message}
  alias RChat.Communities
  alias RChat.Communities.{Channel, Community, Membership}
  alias RChat.Repo

  @history_limit 50

  def subscribe_community(%Community{} = community) do
    Phoenix.PubSub.subscribe(RChat.PubSub, topic(community))
  end

  defp topic(%Community{id: id}), do: "community_chat:#{id}"
  defp topic(%Channel{community_id: id}), do: "community_chat:#{id}"

  @doc """
  Returns the latest messages of a channel in chronological order.

  `:before` takes a message id and returns the page of history right
  above it, for upward pagination.
  """
  def list_messages(%Channel{} = channel, opts \\ []) do
    limit = Keyword.get(opts, :limit, @history_limit)

    query =
      from(m in Message,
        where: m.channel_id == ^channel.id and is_nil(m.deleted_at),
        order_by: [desc: m.id],
        limit: ^limit,
        preload: [:author]
      )

    query =
      case Keyword.get(opts, :before) do
        nil -> query
        before_id -> where(query, [m], m.id < ^before_id)
      end

    query
    |> Repo.all()
    |> Enum.reverse()
  end

  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  @doc """
  Creates a message in a channel for the scope's user and broadcasts
  `{:message_created, message}` to the channel subscribers. Requires
  the send_messages permission in the channel's community.
  """
  def create_message(
        %Scope{user: user} = scope,
        %Community{} = community,
        %Channel{} = channel,
        attrs
      ) do
    true = channel.community_id == community.id

    if Communities.permitted?(scope, community, :send_messages) do
      insert =
        %Message{channel_id: channel.id, author_id: user.id}
        |> Message.changeset(attrs)
        |> Repo.insert()

      with {:ok, message} <- insert do
        message = %{message | author: user, channel: channel}
        Phoenix.PubSub.broadcast(RChat.PubSub, topic(channel), {:message_created, message})
        {:ok, message}
      end
    else
      {:error, :unauthorized}
    end
  end

  ## Read states

  @doc """
  Marks the whole channel as read for the scope's user.
  """
  def mark_channel_read(%Scope{user: user}, %Channel{} = channel) do
    last_id =
      from(m in Message, where: m.channel_id == ^channel.id, select: max(m.id))
      |> Repo.one()

    if last_id do
      now = DateTime.utc_now()

      Repo.insert!(
        %ChannelReadState{
          user_id: user.id,
          channel_id: channel.id,
          last_read_message_id: last_id
        },
        on_conflict: [set: [last_read_message_id: last_id, updated_at: now]],
        conflict_target: [:user_id, :channel_id]
      )
    end

    :ok
  end

  @doc """
  Returns the id of the first unread message of a channel, nil when
  everything was read.
  """
  def first_unread_id(%Scope{user: user}, %Channel{} = channel) do
    last_read =
      from(rs in ChannelReadState,
        where: rs.user_id == ^user.id and rs.channel_id == ^channel.id,
        select: rs.last_read_message_id
      )
      |> Repo.one()

    from(m in Message,
      where: m.channel_id == ^channel.id and is_nil(m.deleted_at),
      where: m.id > ^(last_read || 0),
      select: min(m.id)
    )
    |> Repo.one()
  end

  def unread_channel_ids(%Scope{user: user}, %Community{} = community) do
    from(ch in Channel,
      where: ch.community_id == ^community.id,
      left_join: rs in ChannelReadState,
      on: rs.channel_id == ch.id and rs.user_id == ^user.id,
      join: m in Message,
      on: m.channel_id == ch.id and is_nil(m.deleted_at),
      where: m.id > coalesce(rs.last_read_message_id, 0),
      select: ch.id,
      distinct: true
    )
    |> Repo.all()
    |> MapSet.new()
  end

  def unread_community_ids(%Scope{user: user}) do
    from(ch in Channel,
      join: mem in Membership,
      on: mem.community_id == ch.community_id and mem.user_id == ^user.id,
      left_join: rs in ChannelReadState,
      on: rs.channel_id == ch.id and rs.user_id == ^user.id,
      join: m in Message,
      on: m.channel_id == ch.id and is_nil(m.deleted_at),
      where: m.id > coalesce(rs.last_read_message_id, 0),
      select: ch.community_id,
      distinct: true
    )
    |> Repo.all()
    |> MapSet.new()
  end
end
