defmodule RChat.Communities.Membership do
  use Ecto.Schema
  import Ecto.Changeset

  schema "memberships" do
    field :nickname, :string

    belongs_to :user, RChat.Accounts.User
    belongs_to :community, RChat.Communities.Community

    many_to_many :roles, RChat.Communities.Role,
      join_through: "membership_roles",
      on_replace: :delete

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:nickname])
    |> validate_length(:nickname, min: 1, max: 32)
    |> unique_constraint([:community_id, :user_id])
  end
end
