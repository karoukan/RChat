defmodule RChat.Repo.Migrations.CreateRolesAndMemberships do
  use Ecto.Migration

  def change do
    create table(:roles) do
      add :name, :string, null: false
      add :color, :string
      add :permissions, :integer, null: false, default: 0
      add :position, :integer, null: false, default: 0
      add :is_default, :boolean, null: false, default: false
      add :community_id, references(:communities, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:roles, [:community_id, :name])

    create table(:memberships) do
      add :nickname, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :community_id, references(:communities, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:memberships, [:community_id, :user_id])
    create index(:memberships, [:user_id])

    create table(:membership_roles, primary_key: false) do
      add :membership_id, references(:memberships, on_delete: :delete_all), null: false
      add :role_id, references(:roles, on_delete: :delete_all), null: false
    end

    create unique_index(:membership_roles, [:membership_id, :role_id])
    create index(:membership_roles, [:role_id])
  end
end
