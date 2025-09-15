defmodule ExDoubleEntry.Repo.Migrations.ExDoubleEntryMoney do
  use Ecto.Migration

  def change do
    json_type =
      if Application.get_env(:ex_double_entry, :db) == :postgres,
        do: :jsonb,
        else: :json

    create table(:"#{ExDoubleEntry.db_table_prefix()}account_balances") do
      add(:identifier, :string, null: false)
      add(:currency, :string, null: false)
      add(:scope, :string, null: false, default: "")
      add(:balance_amount, :bigint, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(
      index(
        :"#{ExDoubleEntry.db_table_prefix()}account_balances",
        [:scope, :currency, :identifier],
        unique: true,
        name: :scope_currency_identifier_index
      )
    )

    create table(:"#{ExDoubleEntry.db_table_prefix()}lines") do
      add(:account_identifier, :string, null: false)
      add(:account_scope, :string, null: false, default: "")
      add(:currency, :string, null: false)
      add(:amount, :bigint, null: false)
      add(:balance_amount, :bigint, null: false)
      add(:code, :string, null: false)
      add(:partner_identifier, :string, null: false)
      add(:partner_scope, :string, null: false, default: "")
      add(:metadata, json_type)
      add(:partner_line_id, references(:"#{ExDoubleEntry.db_table_prefix()}lines"))

      add(:account_balance_id, references(:"#{ExDoubleEntry.db_table_prefix()}account_balances"),
        null: false
      )

      timestamps(type: :utc_datetime_usec)
    end

    create(
      index(
        :"#{ExDoubleEntry.db_table_prefix()}lines",
        [:code, :account_identifier, :currency, :inserted_at],
        name: :code_account_identifier_currency_inserted_at_index
      )
    )

    create(
      index(
        :"#{ExDoubleEntry.db_table_prefix()}lines",
        [:account_scope, :account_identifier, :currency, :inserted_at],
        name: :account_scope_account_identifier_currency_inserted_at_index
      )
    )
  end
end
