defmodule RChat.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :content, :text, null: false
      add :edited_at, :utc_datetime_usec
      add :deleted_at, :utc_datetime_usec
      add :channel_id, references(:channels, on_delete: :delete_all), null: false
      add :author_id, references(:users, on_delete: :nilify_all)
      add :reply_to_id, references(:messages, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:messages, [:channel_id])
    create index(:messages, [:author_id])
    create index(:messages, [:reply_to_id])
  end
end
