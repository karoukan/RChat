defmodule RChat.Chat.ChannelReadState do
  use Ecto.Schema

  schema "channel_read_states" do
    belongs_to :user, RChat.Accounts.User
    belongs_to :channel, RChat.Communities.Channel
    belongs_to :last_read_message, RChat.Chat.Message

    timestamps(type: :utc_datetime_usec)
  end
end
