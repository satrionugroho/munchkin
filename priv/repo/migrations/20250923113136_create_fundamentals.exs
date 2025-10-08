defmodule Munchkin.Repo.Migrations.CreateFundamentals do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"")

    create table(:balance_sheets, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()"))
      add(:asset_id, references(:assets, on_delete: :nothing), null: false)
      add(:ref_id, references(:asset_sources, on_delete: :nothing, type: :uuid), null: false)
      add(:period, :string, null: false)
      add(:conversion_rate, :decimal)
      add(:filling_date, :date, null: false)
      add(:ccy, :string, null: false, size: 3)
      add(:yearly, :boolean, default: false)
      add(:cash_equivalent, :decimal)
      add(:short_term_investment, :decimal)
      add(:account_receivable, :decimal)
      add(:inventories, :decimal)
      add(:other_current_asset, :decimal)
      add(:total_current_asset, :decimal)
      add(:property_plant_equipment, :decimal)
      add(:intagible_assets, :decimal)
      add(:other_non_current_asset, :decimal)
      add(:total_assets, :decimal)
      add(:account_payable, :decimal)
      add(:short_term_debt, :decimal)
      add(:other_current_liabilities, :decimal)
      add(:total_current_liabilities, :decimal)
      add(:long_term_debt, :decimal)
      add(:other_long_term_debt, :decimal)
      add(:total_liabilities, :decimal)
      add(:shareholders_equity_in_company, :decimal)
      add(:non_controlling_interest, :decimal)
      add(:total_equity, :decimal)
      add(:total_liabilities_and_equity, :decimal)
      add(:rounding, :decimal)
      add(:metadata, :jsonb, default: "{}")
    end

    create table(:cashflows, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()"))
      add(:asset_id, references(:assets, on_delete: :nothing), null: false)
      add(:ref_id, references(:asset_sources, on_delete: :nothing, type: :uuid), null: false)
      add(:period, :string, null: false)
      add(:filling_date, :date, null: false)
      add(:ccy, :string, null: false, size: 3)
      add(:yearly, :boolean, default: false)
      add(:conversion_rate, :decimal)

      # operating
      add(:net_income, :decimal)
      add(:stock_based_expense, :decimal)
      add(:operating_income, :decimal)
      add(:operating_expense, :decimal)
      add(:depreciation_and_amortization, :decimal)
      add(:other_non_cash_items, :decimal)
      add(:net_cash_operating_activities, :decimal)

      # investing
      add(:capex, :decimal)
      add(:other_investing_activities, :decimal)
      add(:investing_income, :decimal)
      add(:investing_expense, :decimal)
      add(:net_cash_from_investing, :decimal)

      # financing
      add(:financing_income, :decimal)
      add(:financing_expense, :decimal)
      add(:other_financing_activities, :decimal)
      add(:net_cash_from_financing, :decimal)

      # cash
      add(:change_in_cash, :decimal)
      add(:exchange_rate, :decimal)
      add(:cash_in_beginning_period, :decimal)
      add(:cash_in_end_period, :decimal)
      add(:rounding, :decimal)
      add(:metadata, :jsonb, default: "{}")
    end

    create table(:income_statements, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()"))
      add(:asset_id, references(:assets, on_delete: :nothing), null: false)
      add(:ref_id, references(:asset_sources, on_delete: :nothing, type: :uuid), null: false)
      add(:conversion_rate, :decimal)
      add(:period, :string, null: false)
      add(:ccy, :string, null: false, size: 3)
      add(:filling_date, :date, null: false)
      add(:yearly, :boolean, default: false)
      add(:revenue, :decimal)
      add(:cogs, :decimal)
      add(:gross_profit, :decimal)
      add(:sales_marketing, :decimal)
      add(:research_development, :decimal)
      add(:general_administrative, :decimal)
      add(:opex, :decimal)
      add(:operating_income, :decimal)
      add(:other_operating_income, :decimal)
      add(:income_before_tax, :decimal)
      add(:income_tax_expense, :decimal)
      add(:net_income, :decimal)
      add(:non_controlling_interest, :decimal)
      add(:net_income_to_shareholders, :decimal)
      add(:basic_eps, :decimal)
      add(:diluted_eps, :decimal)
      add(:rounding, :decimal)
      add(:metadata, :jsonb, default: "{}")
    end

    create unique_index(:balance_sheets, [:asset_id, :ref_id, :period])
    create unique_index(:cashflows, [:asset_id, :ref_id, :period])
    create unique_index(:income_statements, [:asset_id, :ref_id, :period])
  end

  def down do
    drop(table(:balance_sheets))
    drop(table(:cashflows))
    drop(table(:income_statements))
  end
end
