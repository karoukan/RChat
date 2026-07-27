defmodule RChat.Chat do
  @moduledoc """
  The Chat context: messages and read states.

  Writes are checked against the caller's membership and permissions,
  reads expect a channel that was already fetched through a scoped
  `RChat.Communities` function.
  """

  import Ecto.Query, warn: false

  alias RChat.Accounts.Scope
  alias RChat.Chat.Message
  alias RChat.Communities
  alias RChat.Communities.{Channel, Community}
  alias RChat.Repo

  @history_limit 50

  def subscribe_channel(%Channel{} = channel) do
    Phoenix.PubSub.subscribe(RChat.PubSub, topic(channel))
  end

  def unsubscribe_channel(%Channel{} = channel) do
    Phoenix.PubSub.unsubscribe(RChat.PubSub, topic(channel))
  end

  defp topic(channel), do: "channel:#{channel.id}"

  @doc """
  Returns the latest messages of a channel in chronological order.
  """
  def list_messages(%Channel{} = channel, opts \\ []) do
    limit = Keyword.get(opts, :limit, @history_limit)

    from(m in Message,
      where: m.channel_id == ^channel.id and is_nil(m.deleted_at),
      order_by: [desc: m.id],
      limit: ^limit,
      preload: [:author]
    )
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
        message = %{message | author: user}
        Phoenix.PubSub.broadcast(RChat.PubSub, topic(channel), {:message_created, message})
        {:ok, message}
      end
    else
      {:error, :unauthorized}
    end
  end
end
