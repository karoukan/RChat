defmodule RChat.Repo do
  use Ecto.Repo,
    otp_app: :rchat,
    adapter: Ecto.Adapters.SQLite3
end
