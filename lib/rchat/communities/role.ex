defmodule RChat.Communities.Role do
  use Ecto.Schema
  import Ecto.Changeset

  schema "roles" do
    field :name, :string
    field :color, :string
    field :permissions, :integer, default: 0
    field :position, :integer, default: 0
    field :is_default, :boolean, default: false

    belongs_to :community, RChat.Communities.Community

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :color, :permissions, :position])
    |> validate_required([:name, :permissions])
    |> validate_length(:name, min: 1, max: 50)
    |> validate_format(:color, ~r/^#[0-9a-f]{6}$/i, message: "must be a hex color like #5a3b8c")
    |> validate_number(:permissions, greater_than_or_equal_to: 0)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> unique_constraint([:community_id, :name])
  end
end
