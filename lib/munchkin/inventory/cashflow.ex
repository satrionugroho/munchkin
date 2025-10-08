defmodule Munchkin.Inventory.Cashflow do
  use Ecto.Schema

  import Ecto.Changeset, warn: false

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "cashflows" do
    field :period, :string
    field :filling_date, :date

    field :ccy, :string
    field :yearly, :boolean, default: false
    field :conversion_rate, :decimal
    field :rounding, :decimal

    field :net_income, :decimal
    field :stock_based_expense, :decimal
    field :operating_income, :decimal
    field :operating_expense, :decimal
    field :depreciation_and_amortization, :decimal
    field :other_non_cash_items, :decimal
    field :net_cash_operating_activities, :decimal
    field :capex, :decimal
    field :other_investing_activities, :decimal
    field :investing_income, :decimal
    field :investing_expense, :decimal
    field :net_cash_from_investing, :decimal
    field :financing_income, :decimal
    field :financing_expense, :decimal
    field :other_financing_activities, :decimal
    field :net_cash_from_financing, :decimal
    field :change_in_cash, :decimal
    field :exchange_rate, :decimal
    field :cash_in_beginning_period, :decimal
    field :cash_in_end_period, :decimal
    field :metadata, :map, default: %{}

    belongs_to :asset, Munchkin.Inventory.Asset

    belongs_to :source, Munchkin.Inventory.AssetSource,
      primary_key: true,
      foreign_key: :ref_id,
      type: Ecto.UUID
  end

  def key, do: "cashflow"

  def changeset(cashflow, attrs \\ %{}) do
    cashflow
    |> cast(attrs, [
      :period,
      :filling_date,
      :ccy,
      :conversion_rate,
      :rounding,
      :yearly,
      :net_income,
      :stock_based_expense,
      :operating_income,
      :operating_expense,
      :depreciation_and_amortization,
      :other_non_cash_items,
      :net_cash_operating_activities,
      :capex,
      :other_investing_activities,
      :investing_income,
      :investing_expense,
      :net_cash_from_investing,
      :financing_income,
      :financing_expense,
      :other_financing_activities,
      :net_cash_from_financing,
      :change_in_cash,
      :exchange_rate,
      :cash_in_beginning_period,
      :cash_in_end_period,
      :metadata
    ])
    |> Munchkin.Utils.Relations.cast_relations(
      [asset: Munchkin.Inventory.Asset, source: Munchkin.Inventory.AssetSource],
      attrs
    )
    |> validate_required([:period, :filling_date, :ccy])
  end
end
