defmodule Munchkin.Inventory.BalanceSheet do
  use Ecto.Schema

  import Ecto.Changeset, warn: false

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "balance_sheets" do
    field :period, :string
    field :filling_date, :date

    field :ccy, :string
    field :yearly, :boolean, default: false
    field :conversion_rate, :decimal
    field :rounding, :decimal

    field :cash_equivalent, :decimal
    field :short_term_investment, :decimal
    field :account_receivable, :decimal
    field :inventories, :decimal
    field :other_current_asset, :decimal
    field :total_current_asset, :decimal
    field :property_plant_equipment, :decimal
    field :intagible_assets, :decimal
    field :other_non_current_asset, :decimal
    field :total_assets, :decimal
    field :account_payable, :decimal
    field :short_term_debt, :decimal
    field :other_current_liabilities, :decimal
    field :total_current_liabilities, :decimal
    field :long_term_debt, :decimal
    field :other_long_term_debt, :decimal
    field :total_liabilities, :decimal
    field :shareholders_equity_in_company, :decimal
    field :non_controlling_interest, :decimal
    field :total_equity, :decimal
    field :total_liabilities_and_equity, :decimal
    field :metadata, :map, default: %{}

    belongs_to :asset, Munchkin.Inventory.Asset

    belongs_to :source, Munchkin.Inventory.AssetSource,
      primary_key: true,
      foreign_key: :ref_id,
      type: Ecto.UUID
  end

  def key, do: "balance_sheet"

  def changeset(balance_sheet, attrs \\ %{}) do
    balance_sheet
    |> cast(attrs, [
      :period,
      :filling_date,
      :ccy,
      :conversion_rate,
      :rounding,
      :yearly,
      :cash_equivalent,
      :short_term_investment,
      :account_receivable,
      :inventories,
      :other_current_asset,
      :total_current_asset,
      :property_plant_equipment,
      :intagible_assets,
      :other_non_current_asset,
      :total_assets,
      :account_payable,
      :short_term_debt,
      :other_current_liabilities,
      :total_current_liabilities,
      :long_term_debt,
      :other_long_term_debt,
      :total_liabilities,
      :shareholders_equity_in_company,
      :non_controlling_interest,
      :total_equity,
      :total_liabilities_and_equity,
      :metadata
    ])
    |> Munchkin.Utils.Relations.cast_relations(
      [asset: Munchkin.Inventory.Asset, source: Munchkin.Inventory.AssetSource],
      attrs
    )
    |> validate_required([:period, :filling_date, :ccy])
  end
end
