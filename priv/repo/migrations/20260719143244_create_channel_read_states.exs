defmodule RChat.Repo.Migrations.CreateChannelReadStates do
  use Ecto.Migration

  def change do
    create table(:channel_read_states) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :channel_id, references(:channels, on_delete: :delete_all), null: false
      add :last_read_message_id, references(:messages, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:channel_read_states, [:user_id, :channel_id])
    create index(:channel_read_states, [:channel_id])
    create index(:channel_read_states, [:last_read_message_id])
  end
end
