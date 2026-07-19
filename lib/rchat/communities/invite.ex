defmodule RChat.Communities.Invite do
  use Ecto.Schema
  import Ecto.Changeset

  schema "invites" do
    field :code, :string
    field :expires_at, :utc_datetime
    field :max_uses, :integer
    field :uses, :integer, default: 0

    belongs_to :community, RChat.Communities.Community
    belongs_to :created_by, RChat.Accounts.User

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(invite, attrs) do
    invite
    |> cast(attrs, [:expires_at, :max_uses])
    |> validate_number(:max_uses, greater_than: 0)
    |> put_code()
    |> validate_required([:code])
    |> unique_constraint(:code)
  end

  defp put_code(changeset) do
    case get_field(changeset, :code) do
      nil -> put_change(changeset, :code, generate_code())
      _ -> changeset
    end
  end

  defp generate_code do
    :crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false)
  end
end
