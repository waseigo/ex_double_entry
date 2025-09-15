import Config

config :ex_double_entry, ExDoubleEntry.Repo,
  username: "postgres",
  password: "postgres",
  database: "ex_double_entry_dev",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# When using SQLite
# config :ex_double_entry, ExDoubleEntry.Repo,
#   database: Path.expand("../ex_double_entry_dev.db", __DIR__),
#   pool_size: 5,
#   stacktrace: true,
#   show_sensitive_data_on_connection_error: true
