defmodule ExDoubleEntry.AccountBalance do
  @moduledoc """
  Defines the Ecto schema and operations for account balances.

  ## Schema fields

  - `:identifier` - Unique identifier for the account.
  - `:currency` - Currency code for the balance.
  - `:scope` - Optional scope for the account.
  - `:balance_amount` - The current balance as an integer (in the smallest unit of the currency).
  - Timestamps with microsecond precision (`:utc_datetime_usec`).

  ## Key functions

  - `find/1`: Retrieves an `%AccountBalance{}` for a given `%Account{}` without locking.
  - `create!/1`: Creates a new `%AccountBalance{}` with zero balance for an `%Account{}`.
  - `for_account!/2`: Retrieves or creates an `%AccountBalance{}` for an `%Account{}`, with optional locking.
  - `for_account/2`: Retrieves an `%AccountBalance{}` for an `%Account{}`, with optional locking.
  - `lock!/1`: Locks and retrieves an `%AccountBalance{}` for an `%Account{}` (uses row-level locking for Postgres/MySQL; relies on transaction serialization in WAL mode for SQLite3).
  - `lock_multi!/2`: Locks multiple accounts in a transaction and executes a function atomically (sorted to avoid deadlocks).
  - `update_balance!/2`: Updates the balance of a locked `%AccountBalance{}`.

  ## Database considerations

  - Supports Postgres (default), MySQL, and SQLite3 via the `:db` compile-time configuration.
  - For SQLite3 (`db: :sqlite3`), row-level locking is skipped, relying on WAL mode for serialization; use in environments of low concurrency / write contention only.
  - Unique constraint on `[:scope, :currency, :identifier]` with adapter-specific naming (prefixed accordingly for SQLite3).

  See `ExDoubleEntry.Transfer` for transfer operations that use these balances.
  """

  use Ecto.Schema
  import Ecto.{Changeset, Query}

  alias ExDoubleEntry.{Account, AccountBalance}

  @db Application.compile_env(:ex_double_entry, :db, :postgres)

  schema "#{ExDoubleEntry.db_table_prefix()}account_balances" do
    field(:identifier, ExDoubleEntry.EctoType.Identifier)
    field(:currency, ExDoubleEntry.EctoType.Currency)
    field(:scope, ExDoubleEntry.EctoType.Scope)
    field(:balance_amount, :integer)

    timestamps(type: :utc_datetime_usec)
  end

  defp changeset(params) do
    %AccountBalance{}
    |> cast(params, [:identifier, :currency, :scope, :balance_amount])
    |> validate_required([:identifier, :currency, :balance_amount])
    |> unique_constraint(:identifier, name: constraint_name())
  end

  @dialyzer {:nowarn_function, constraint_name: 0}
  defp constraint_name do
    base_name = "scope_currency_identifier_index"

    case @db do
      :sqlite3 -> "#{ExDoubleEntry.db_table_prefix()}account_balances_#{base_name}"
      db when db in [:postgres, :mysql] -> base_name
    end
    |> String.to_atom()
  end

  def find(%Account{} = account) do
    for_account(account, lock: false)
  end

  def create!(%Account{identifier: identifier, currency: currency, scope: scope}) do
    %{
      identifier: identifier,
      currency: currency,
      scope: scope,
      balance_amount: 0
    }
    |> changeset()
    |> ExDoubleEntry.repo().insert!()
  end

  def for_account!(%Account{} = account) do
    for_account!(account, lock: false)
  end

  def for_account!(%Account{} = account, lock: lock) do
    for_account(account, lock: lock) || create!(account)
  end

  def for_account(nil), do: nil

  def for_account(%Account{} = account) do
    for_account(account, lock: false)
  end

  def for_account(
        %Account{identifier: identifier, currency: currency, scope: scope},
        lock: lock
      ) do
    from(
      ab in AccountBalance,
      where: ab.identifier == ^identifier,
      where: ab.currency == ^currency
    )
    |> scope_cond(scope)
    |> lock_cond(lock)
    |> ExDoubleEntry.repo().one()
  end

  defp scope_cond(query, scope) do
    case scope do
      nil -> where(query, [ab], ab.scope == "")
      _ -> where(query, [ab], ab.scope == ^scope)
    end
  end

  defp lock_cond(query, lock) do
    case lock do
      true when @db != :sqlite3 -> lock(query, "FOR SHARE NOWAIT")
      _ -> query
    end
  end

  def lock!(%Account{} = account) do
    for_account(account, lock: true)
  end

  def lock_multi!(accounts, fun) do
    ExDoubleEntry.repo().transaction(fn ->
      accounts |> Enum.sort() |> Enum.each(fn account -> lock!(account) end)
      fun.()
    end)
  end

  def update_balance!(%Account{} = account, balance_amount) do
    account
    |> lock!()
    |> Ecto.Changeset.change(balance_amount: balance_amount)
    |> ExDoubleEntry.repo().update!()
  end
end
