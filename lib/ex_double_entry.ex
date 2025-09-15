defmodule ExDoubleEntry do
  @moduledoc """
  Contains the main public API, delegating to children modules.

  # Key functions (delegated)

  - `make_account!/2`: Creates a new account with zero balance.
  - `lookup_account!/2`: Retrieves an existing account.
  - `lock_accounts/2`: Locks multiple accounts and executes a function atomically (only on PostgreSQL and MySQL).
  - `transfer!/1`: Performs a validated, atomic transfer (raising on errors).
  - `transfer/1`: Non-raising variant of `transfer!/1`.
  """
  @db_table_prefix Application.compile_env(:ex_double_entry, :db_table_prefix, nil)
  @repo Application.compile_env(:ex_double_entry, :repo, ExDoubleEntry.Repo)

  def db_table_prefix, do: @db_table_prefix

  def repo, do: @repo

  @doc """
  ## Examples

  iex> ExDoubleEntry.make_account!(:savings).__struct__
  ExDoubleEntry.Account
  """
  defdelegate make_account!(identifier, opts \\ []), to: ExDoubleEntry.Account, as: :make!

  @doc """
  ## Examples

  iex> ExDoubleEntry.lookup_account!(:savings, currency: :USD)
  nil
  """
  defdelegate lookup_account!(identifier, opts \\ []), to: ExDoubleEntry.Account, as: :lookup!

  @doc """
  ## Examples

  iex> [ExDoubleEntry.make_account!(:savings)] |> ExDoubleEntry.lock_accounts(fn -> true end)
  `{:ok, true}`
  """
  defdelegate lock_accounts(accounts, fun), to: ExDoubleEntry.AccountBalance, as: :lock_multi!

  @doc """
  ## Examples

  iex> %ExDoubleEntry.Transfer{
  ...>   money: Money.new(42, :USD),
  ...>   from: %ExDoubleEntry.Account{identifier: :checking, currency: :USD, balance: Money.new(42, :USD), positive_only?: false},
  ...>   to: %ExDoubleEntry.Account{identifier: :savings, currency: :USD, balance: Money.new(0, :USD)},
  ...>   code: :deposit
  ...> } |> ExDoubleEntry.transfer!() |> Tuple.to_list() |> List.first()
  :ok
  """
  defdelegate transfer!(transfer), to: ExDoubleEntry.Transfer, as: :perform!

  def transfer(transfer) do
    ExDoubleEntry.Transfer.perform!(transfer, ensure_accounts: false)
  end
end
