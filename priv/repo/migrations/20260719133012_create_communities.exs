defmodule RChat.Repo.Migrations.CreateCommunities do
  use Ecto.Migration

  def change do
    create table(:communities) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :string
      add :owner_id, references(:users, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:communities, [:slug])
    create index(:communities, [:owner_id])

    create table(:channels) do
      add :name, :string, null: false
      add :topic, :string
      add :position, :integer, null: false, default: 0
      add :community_id, references(:communities, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:channels, [:community_id, :name])
  end
end
