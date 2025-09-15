defmodule ExDoubleEntry.Repo do
  @moduledoc false
  @db Application.compile_env(:ex_double_entry, :db, :postgres)

  @db_adapter (case @db do
                 :sqlite3 -> Ecto.Adapters.SQLite3
                 :postgres -> Ecto.Adapters.Postgres
                 :mysql -> Ecto.Adapters.MyXQL
               end)

  use Ecto.Repo,
    otp_app: :ex_double_entry,
    adapter: @db_adapter
end
