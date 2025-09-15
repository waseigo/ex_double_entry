defmodule ExDoubleEntry.Guard do
  @moduledoc """
  Provides guard functions for validating `ExDoubleEntry.Transfer` structs before performing double-entry accounting operations.

  These guards ensure transfers meet criteria such as positive amounts, valid configurations, matching currencies, and sufficient balances for positive-only accounts. Each function returns `{:ok, transfer}` on success or `{:error, reason, message}` on failure.

  ## Key functions

  - `positive_amount?/1`: Ensures the transfer amount is positive.
  - `valid_definition?/1`: Verifies the transfer code and account pair are defined in the application configuration (:transfers).
  - `matching_currency?/1`: Checks that the currencies of the money, from-account, and to-account match.
  - `positive_balance_if_enforced?/1`: Ensures the from-account has sufficient balance if it is marked as positive-only (configured via `:accounts`).

  ## Configuration dependencies

  - Relies on `:transfers` config for valid codes and pairs.
  - Uses `:accounts` config for `:positive_only` flags.

  See `ExDoubleEntry.Transfer` for high-level transfer APIs.
  """
  alias ExDoubleEntry.Transfer

  @doc """
  ## Examples

  iex> %Transfer{money: Money.new(42, :USD), from: nil, to: nil, code: nil} |> Guard.positive_amount?()
  `{:ok, %Transfer{money: Money.new(42, :USD), from: nil, to: nil, code: nil}}`

  iex> %Transfer{money: Money.new(-42, :USD), from: nil, to: nil, code: nil} |> Guard.positive_amount?()
  `{:error, :positive_amount_only, ""}`
  """
  def positive_amount?(%Transfer{money: money} = transfer) do
    case Money.positive?(money) do
      true -> {:ok, transfer}
      false -> {:error, :positive_amount_only, ""}
    end
  end

  @doc """
  ## Examples

  iex> %Transfer{
  ...>   money: nil,
  ...>   from: %Account{identifier: :checking, currency: :USD},
  ...>   to: %Account{identifier: :savings, currency: :USD},
  ...>   code: :deposit
  ...> } |> Guard.valid_definition?()
  {
    :ok,
    %Transfer{
      money: nil,
      code: :deposit,
      from: %Account{identifier: :checking, currency: :USD},
      to: %Account{identifier: :savings, currency: :USD},
    }
  }

  iex> %Transfer{
  ...>   money: nil,
  ...>   from: %Account{identifier: :checking, currency: :USD},
  ...>   to: %Account{identifier: :savings, currency: :USD},
  ...>   code: :give_away
  ...> } |> Guard.valid_definition?()
  `{:error, :undefined_transfer_code, "Transfer code :give_away is undefined."}`

  iex> %Transfer{
  ...>   money: nil,
  ...>   from: %Account{identifier: :checking, currency: :USD},
  ...>   to: %Account{identifier: :savings, currency: :USD},
  ...>   code: :withdraw
  ...> } |> Guard.valid_definition?()
  `{:error, :undefined_transfer_pair, "Transfer pair :checking -> :savings does not exist for code :withdraw."}`
  """
  def valid_definition?(%Transfer{from: from, to: to, code: code} = transfer) do
    with {:ok, pairs} <-
           :ex_double_entry
           |> Application.fetch_env!(:transfers)
           |> Map.fetch(code),
         true <- Enum.member?(pairs, {from.identifier, to.identifier}) do
      {:ok, transfer}
    else
      :error ->
        {:error, :undefined_transfer_code, "Transfer code #{inspect(code)} is undefined."}

      false ->
        {:error, :undefined_transfer_pair,
         "Transfer pair #{inspect(from.identifier)} -> #{inspect(to.identifier)} does not exist for code #{inspect(code)}."}
    end
  end

  @doc """
  ## Examples

  iex> %Transfer{
  ...>   money: Money.new(42, :USD),
  ...>   from: %Account{identifier: :checking, currency: :USD},
  ...>   to: %Account{identifier: :savings, currency: :USD},
  ...>   code: :deposit
  ...> } |> Guard.matching_currency?()
  {
    :ok,
    %Transfer{
      money: Money.new(42, :USD),
      code: :deposit,
      from: %Account{identifier: :checking, currency: :USD},
      to: %Account{identifier: :savings, currency: :USD},
    }
  }

  iex> %Transfer{
  ...>   money: Money.new(42, :AUD),
  ...>   from: %Account{identifier: :checking, currency: :USD},
  ...>   to: %Account{identifier: :savings, currency: :USD},
  ...>   code: :deposit
  ...> } |> Guard.matching_currency?()
  `{:error, :mismatched_currencies, "Attempted to transfer :AUD from :checking in :USD to :savings in :USD."}`

  iex> %Transfer{
  ...>   money: Money.new(42, :USD),
  ...>   from: %Account{identifier: :checking, currency: :USD},
  ...>   to: %Account{identifier: :savings, currency: :AUD},
  ...>   code: :deposit
  ...> } |> Guard.matching_currency?()
  `{:error, :mismatched_currencies, "Attempted to transfer :USD from :checking in :USD to :savings in :AUD."}`
  """
  def matching_currency?(%Transfer{money: money, from: from, to: to} = transfer) do
    if from.currency == money.currency and to.currency == money.currency do
      {:ok, transfer}
    else
      {:error, :mismatched_currencies,
       "Attempted to transfer #{inspect(money.currency)} from #{inspect(from.identifier)} in #{inspect(from.currency)} to #{inspect(to.identifier)} in #{inspect(to.currency)}."}
    end
  end

  @doc """
  ## Examples

  iex> %Transfer{
  ...>   money: Money.new(42, :USD),
  ...>   from: %Account{identifier: :checking, currency: :USD, balance: Money.new(42, :USD), positive_only?: true},
  ...>   to: %Account{identifier: :savings, currency: :USD},
  ...>   code: :deposit
  ...> } |> Guard.positive_balance_if_enforced?()
  {
    :ok,
    %Transfer{
      money: Money.new(42, :USD),
      code: :deposit,
      from: %Account{identifier: :checking, currency: :USD, balance: Money.new(42, :USD), positive_only?: true},
      to: %Account{identifier: :savings, currency: :USD},
    }
  }

  iex> %Transfer{
  ...>   money: Money.new(42, :USD),
  ...>   from: %Account{identifier: :checking, currency: :USD, balance: Money.new(10, :USD), positive_only?: false},
  ...>   to: %Account{identifier: :savings, currency: :USD},
  ...>   code: :deposit
  ...> } |> Guard.positive_balance_if_enforced?()
  {
    :ok,
    %Transfer{
      money: Money.new(42, :USD),
      code: :deposit,
      from: %Account{identifier: :checking, currency: :USD, balance: Money.new(10, :USD), positive_only?: false},
      to: %Account{identifier: :savings, currency: :USD},
    }
  }

  iex> %Transfer{
  ...>   money: Money.new(42, :USD),
  ...>   from: %Account{identifier: :checking, currency: :USD, balance: Money.new(10, :USD)},
  ...>   to: %Account{identifier: :savings, currency: :USD},
  ...>   code: :deposit
  ...> } |> Guard.positive_balance_if_enforced?()
  {
    :ok,
    %Transfer{
      money: Money.new(42, :USD),
      code: :deposit,
      from: %Account{identifier: :checking, currency: :USD, balance: Money.new(10, :USD), positive_only?: nil},
      to: %Account{identifier: :savings, currency: :USD},
    }
  }

  iex> %Transfer{
  ...>   money: Money.new(42, :USD),
  ...>   from: %Account{identifier: :checking, currency: :USD, balance: Money.new(10, :USD), positive_only?: true},
  ...>   to: %Account{identifier: :savings, currency: :USD},
  ...>   code: :deposit
  ...> } |> Guard.positive_balance_if_enforced?()
  `{:error, :insufficient_balance, "Transfer amount: 42, :checking balance amount: 10"}`
  """
  def positive_balance_if_enforced?(%Transfer{money: money, from: from} = transfer) do
    if !!from.positive_only? and Money.cmp(from.balance, money) == :lt do
      {:error, :insufficient_balance,
       "Transfer amount: #{money.amount}, #{inspect(from.identifier)} balance amount: #{from.balance.amount}"}
    else
      {:ok, transfer}
    end
  end
end
