defmodule ExDoubleEntry.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children =
      case Application.fetch_env(:ex_double_entry, :ecto_repos) do
        # ecto_repos are only required for development and test
        {:ok, repos} -> repos
        _ -> []
      end

    opts = [strategy: :one_for_one, name: ExDoubleEntry.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
