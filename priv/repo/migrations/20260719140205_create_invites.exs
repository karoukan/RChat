defmodule RChat.Repo.Migrations.CreateInvites do
  use Ecto.Migration

  def change do
    create table(:invites) do
      add :code, :string, null: false
      add :expires_at, :utc_datetime
      add :max_uses, :integer
      add :uses, :integer, null: false, default: 0
      add :community_id, references(:communities, on_delete: :delete_all), null: false
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:invites, [:code])
    create index(:invites, [:community_id])
    create index(:invites, [:created_by_id])
  end
end
