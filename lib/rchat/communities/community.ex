defmodule RChat.Communities.Community do
  use Ecto.Schema
  import Ecto.Changeset

  schema "communities" do
    field :name, :string
    field :slug, :string
    field :description, :string

    belongs_to :owner, RChat.Accounts.User
    has_many :channels, RChat.Communities.Channel
    has_many :memberships, RChat.Communities.Membership
    has_many :roles, RChat.Communities.Role

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(community, attrs) do
    community
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:description, max: 1000)
    |> put_slug()
    |> validate_required([:slug])
    |> unique_constraint(:slug)
  end

  defp put_slug(changeset) do
    case {get_field(changeset, :slug), get_change(changeset, :name)} do
      {nil, name} when is_binary(name) -> put_change(changeset, :slug, slugify(name))
      _ -> changeset
    end
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/u, "")
    |> String.replace(~r/[\s-]+/, "-")
    |> String.trim("-")
  end
end
