defmodule ExDoubleEntry.Transfer do
  @moduledoc """
  Defines the struct and operations for performing atomic transfers.

  Transfers represent movements of money between accounts, enforcing double-entry principles (debit and credit pairs). Operations are atomic, using account locking and Ecto transactions to ensure consistency.

  ## Struct fields

  - `:money` - Required amount to transfer as a Money struct (positive only).
  - `:from` - Required source Account struct.
  - `:to` - Required destination Account struct.
  - `:code` - Required transfer code (atom, validated against config).
  - `:metadata` - Optional map for additional transaction details.

  ## Key functions

  - `perform!/1` and `perform!/2`: Validates and executes the transfer, raising on errors. Optional `:ensure_accounts` (default: `true`) creates accounts if missing.
  - `perform/1` and `perform/2`: Non-raising variants, returning the `%Transfer{}` struct on success.

  ## Validation

  Uses `ExDoubleEntry.Guard` for checks: positive amount, valid code/pair, matching currencies, sufficient balance (if positive-only).

  ## Process

  1. Validate transfer.
  2. Lock accounts.
  3. Insert paired debit/credit lines (`ExDoubleEntry.Line`).
  4. Update partner line IDs.
  5. Adjust balances.
  6. Commit transaction.

  ## Database considerations

  - Atomic via Ecto transactions and `AccountBalance.lock_multi!/2` on PostgreSQL and MySQL.
  - For SQLite3, relies on WAL serialization instead of row-level locking.

  See `ExDoubleEntry.Guard` for validation details, `ExDoubleEntry.Line` for transaction records, and `ExDoubleEntry.AccountBalance` for locking and balances.
  """
  @enforce_keys [:money, :from, :to, :code]
  defstruct [:money, :from, :to, :code, :metadata]

  alias ExDoubleEntry.{Account, AccountBalance, Guard, Line, Transfer}

  def perform!(%Transfer{} = transfer) do
    perform!(transfer, ensure_accounts: true)
  end

  def perform!(transfer_attrs) do
    perform!(transfer_attrs, ensure_accounts: true)
  end

  def perform!(%Transfer{} = transfer, ensure_accounts: ensure_accounts) do
    with {:ok, _} <- Guard.positive_amount?(transfer),
         {:ok, _} <- Guard.valid_definition?(transfer),
         {:ok, _} <- Guard.matching_currency?(transfer),
         {:ok, _} <- Guard.positive_balance_if_enforced?(transfer) do
      perform(transfer, ensure_accounts: ensure_accounts)
    end
  end

  def perform!(transfer_attrs, ensure_accounts: ensure_accounts) do
    Transfer |> struct(transfer_attrs) |> perform!(ensure_accounts: ensure_accounts)
  end

  def perform(%Transfer{} = transfer) do
    perform(transfer, ensure_accounts: true)
  end

  def perform(
        %Transfer{
          money: money,
          from: from,
          to: to,
          code: code,
          metadata: metadata
        } = transfer,
        ensure_accounts: ensure_accounts
      ) do
    {from, to} = ensure_accounts_if_needed(ensure_accounts, from, to)

    AccountBalance.lock_multi!([from, to], fn ->
      line1 =
        Line.insert!(Money.neg(money),
          account: from,
          partner: to,
          code: code,
          metadata: metadata
        )

      line2 =
        Line.insert!(money,
          account: to,
          partner: from,
          code: code,
          metadata: metadata
        )

      Line.update_partner_line_id!(line1, line2.id)
      Line.update_partner_line_id!(line2, line1.id)

      from_amount = Money.subtract(from.balance, money).amount
      to_amount = Money.add(to.balance, money).amount

      AccountBalance.update_balance!(from, from_amount)
      AccountBalance.update_balance!(to, to_amount)

      transfer
    end)
  end

  defp ensure_accounts_if_needed(true, acc_a, acc_b) do
    {
      acc_a |> AccountBalance.for_account!() |> Account.present(),
      acc_b |> AccountBalance.for_account!() |> Account.present()
    }
  end

  defp ensure_accounts_if_needed(_, acc_a, acc_b) do
    cond do
      is_nil(AccountBalance.for_account(acc_a)) ->
        raise Account.NotFoundError

      is_nil(AccountBalance.for_account(acc_b)) ->
        raise Account.NotFoundError

      true ->
        {acc_a, acc_b}
    end
  end
end
