defmodule ExDoubleEntry.Account do
  @moduledoc """
  Defines the struct and operations for accounts.

  ## Struct fields

  - `:id` - Optional internal ID (from the database).
  - `:identifier` - Required unique identifier for the account (atom or string).
  - `:scope` - Optional scope to differentiate accounts (e.g., user-specific).
  - `:currency` - Required currency code (e.g., `:USD`).
  - `:balance` - Optional current balance as a `%Money{}` struct.
  - `:positive_only?` - Flag indicating if the account balance must remain non-negative.

  ## Key functions

  - `present/1`: Converts an `%AccountBalance{}` schema or `nil` to an `%Account{}` struct.
  - `lookup!/2`: Retrieves an existing `%Account{}` by identifier and options (e.g., currency, scope). Raises `ExDoubleEntry.Account.NotFoundError` if not found.
  - `make!/2`: Creates a new `%Account{}` with zero balance, enforcing required fields and configuration.

  ## Configuration dependencies

  - Uses `:default_currency` from `:ex_double_entry` application config.
  - Checks `:accounts` config for `:positive_only` flag per identifier.

  ## Exceptions

  - `ExDoubleEntry.Account.NotFoundError`: Raised when an account is not found.
  - `ExDoubleEntry.Account.InvalidScopeError`: Raised for invalid scopes (e.g., empty string).

  See `ExDoubleEntry.AccountBalance` for balance-related operations and `ExDoubleEntry.Transfer` for transfers between accounts.
  """
  @enforce_keys [:identifier, :currency]
  defstruct [:id, :identifier, :scope, :currency, :balance, :positive_only?]

  alias ExDoubleEntry.{Account, AccountBalance}

  def present(nil), do: nil

  def present(%AccountBalance{} = params) do
    %Account{
      id: params.id,
      identifier: params.identifier,
      currency: params.currency,
      scope: params.scope,
      positive_only?: positive_only?(params.identifier),
      balance: Money.new(params.balance_amount, params.currency)
    }
  end

  def lookup!(identifier, opts \\ []) do
    opts = [identifier: identifier, currency: currency(opts)] ++ opts

    Account
    |> struct(opts)
    |> AccountBalance.find()
    |> present()
  end

  def make!(identifier, opts \\ []) do
    %Account{
      identifier: identifier,
      currency: currency(opts),
      scope: opts[:scope],
      positive_only?: positive_only?(identifier)
    }
    |> AccountBalance.create!()
    |> present()
  end

  defp currency(opts) do
    opts[:currency] || Application.fetch_env!(:ex_double_entry, :default_currency)
  end

  defp positive_only?(identifier) do
    account_opts =
      :ex_double_entry
      |> Application.fetch_env!(:accounts)
      |> Map.fetch!(identifier)

    !!account_opts[:positive_only]
  end
end

defmodule ExDoubleEntry.Account.NotFoundError do
  @moduledoc """
  Raised when an account is not found.
  """
  defexception message: "Account not found."
end

defmodule ExDoubleEntry.Account.InvalidScopeError do
  @moduledoc """
  Raised for invalid scopes (empty string).
  """
  defexception message: "Invalid scope: empty string not allowed."
end
