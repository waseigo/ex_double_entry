{:ok, _} = Application.ensure_all_started(:ex_machina)
ExUnit.start(timeout: 300_000)

if Application.get_env(:ex_double_entry, :db) == :sqlite3 do
  ExUnit.configure(exclude: [:requires_locking])
end

Ecto.Adapters.SQL.Sandbox.mode(ExDoubleEntry.repo(), :manual)

require Logger
db = Application.fetch_env!(:ex_double_entry, :db)
Logger.info("Running tests with #{db}...")
