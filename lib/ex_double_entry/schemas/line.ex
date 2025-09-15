defmodule ExDoubleEntry.Line do
  @moduledoc """
  Defines the Ecto schema and operations for transaction lines.

  ## Schema fields

  - `:account_identifier` - Identifier of the account for this line.
  - `:account_scope` - Optional scope for the account.
  - `:currency` - Currency code for the transaction.
  - `:amount` - Transaction amount as an integer (in the smallest unit of the currency).
  - `:balance_amount` - Updated balance after this transaction.
  - `:code` - Transaction code.
  - `:partner_identifier` - Identifier of the partner account.
  - `:partner_scope` - Optional scope for the partner account.
  - `:metadata` - Arbitrary map for additional transaction data.
  - `:partner_line_id` - Foreign key to the paired (partner) line.
  - `:account_balance_id` - Foreign key to the associated account balance.
  - Timestamps with microsecond precision (`:utc_datetime_usec`).

  ## Associations

  - `belongs_to :partner_line` - The paired debit/credit line.
  - `belongs_to :account_balance` - The affected account balance.

  ## Key functions

  - `insert!/1`: Inserts a new transaction line for a transfer, computing the updated balance.
  - `update_partner_line_id!/2`: Updates the partner line ID for pairing debits and credits.

  ## Database considerations

  - Table name prefixed via `ExDoubleEntry.db_table_prefix()`.
  - Validates required fields and foreign keys.
  - Used internally by transfer operations to record atomic debits/credits.

  See `ExDoubleEntry.Transfer` for high-level transfer APIs and `ExDoubleEntry.AccountBalance` for balance management.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ExDoubleEntry.{AccountBalance, Line}

  schema "#{ExDoubleEntry.db_table_prefix()}lines" do
    field(:account_identifier, ExDoubleEntry.EctoType.Identifier)
    field(:account_scope, ExDoubleEntry.EctoType.Scope)
    field(:currency, ExDoubleEntry.EctoType.Currency)
    field(:amount, :integer)
    field(:balance_amount, :integer)
    field(:code, ExDoubleEntry.EctoType.Identifier)
    field(:partner_identifier, ExDoubleEntry.EctoType.Identifier)
    field(:partner_scope, ExDoubleEntry.EctoType.Scope)
    field(:metadata, :map)

    belongs_to(:partner_line, Line)
    belongs_to(:account_balance, AccountBalance)

    timestamps(type: :utc_datetime_usec)
  end

  defp changeset(params) do
    %Line{}
    |> cast(params, [
      :account_identifier,
      :account_scope,
      :currency,
      :amount,
      :balance_amount,
      :code,
      :partner_identifier,
      :partner_scope,
      :metadata,
      :account_balance_id,
      :partner_line_id
    ])
    |> validate_required([
      :account_identifier,
      :currency,
      :amount,
      :balance_amount,
      :code,
      :partner_identifier
    ])
    |> foreign_key_constraint(:partner_line_id)
    |> foreign_key_constraint(:account_balance_id)
  end

  def insert!(money, account: account, partner: partner, code: code, metadata: metadata) do
    %{
      account_identifier: account.identifier,
      account_scope: account.scope,
      currency: money.currency,
      code: code,
      amount: money.amount,
      balance_amount: Money.add(account.balance, money).amount,
      partner_identifier: partner.identifier,
      partner_scope: partner.scope,
      metadata: metadata,
      account_balance_id: account.id
    }
    |> changeset()
    |> ExDoubleEntry.repo().insert!()
  end

  def update_partner_line_id!(%Line{} = line, partner_line_id) do
    line
    |> Ecto.Changeset.change(partner_line_id: partner_line_id)
    |> ExDoubleEntry.repo().update!()
  end
end
