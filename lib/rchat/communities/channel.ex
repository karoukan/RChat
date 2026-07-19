defmodule RChat.Communities.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  schema "channels" do
    field :name, :string
    field :topic, :string
    field :position, :integer, default: 0

    belongs_to :community, RChat.Communities.Community

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :topic, :position])
    |> validate_required([:name])
    |> validate_format(:name, ~r/^[a-z0-9-]+$/,
      message: "only lowercase letters, numbers and dashes"
    )
    |> validate_length(:name, min: 2, max: 50)
    |> validate_length(:topic, max: 1000)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> unique_constraint([:community_id, :name])
  end
end
