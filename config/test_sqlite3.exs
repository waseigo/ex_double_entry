import Config

config :ex_double_entry,
  db: :sqlite3

config :ex_double_entry, ExDoubleEntry.Repo,
  database: System.get_env("SQLITE_DB_PATH", "ex_double_entry_test.db"),
  adapter: Ecto.Adapters.SQLite3,
  journal_mode: :wal,
  pool_size: 1,
  pool: Ecto.Adapters.SQL.Sandbox,
  show_sensitive_data_on_connection_error: true,
  timeout: :infinity,
  queue_target: 200,
  queue_interval: 10

config :logger, level: :info
