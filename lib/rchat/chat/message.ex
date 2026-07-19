defmodule RChat.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :content, :string
    field :edited_at, :utc_datetime_usec
    field :deleted_at, :utc_datetime_usec

    belongs_to :channel, RChat.Communities.Channel
    belongs_to :author, RChat.Accounts.User
    belongs_to :reply_to, RChat.Chat.Message

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content])
    |> validate_required([:content])
    |> validate_length(:content, min: 1, max: 4000)
  end
end
