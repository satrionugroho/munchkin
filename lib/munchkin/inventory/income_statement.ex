defmodule Munchkin.Inventory.IncomeStatement do
  use Ecto.Schema

  import Ecto.Changeset, warn: false

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "income_statements" do
    field :period, :string
    field :filling_date, :date

    field :ccy, :string
    field :yearly, :boolean, default: false
    field :conversion_rate, :decimal
    field :rounding, :decimal

    field :revenue, :decimal
    field :cogs, :decimal
    field :gross_profit, :decimal
    field :sales_marketing, :decimal
    field :research_development, :decimal
    field :general_administrative, :decimal
    field :opex, :decimal
    field :operating_income, :decimal
    field :other_operating_income, :decimal
    field :income_before_tax, :decimal
    field :income_tax_expense, :decimal
    field :net_income, :decimal
    field :non_controlling_interest, :decimal
    field :net_income_to_shareholders, :decimal
    field :metadata, :map, default: %{}

    belongs_to :asset, Munchkin.Inventory.Asset

    belongs_to :source, Munchkin.Inventory.AssetSource,
      primary_key: true,
      foreign_key: :ref_id,
      type: Ecto.UUID
  end

  def key, do: "income_statement"

  def changeset(income_statement, attrs \\ %{}) do
    income_statement
    |> cast(attrs, [
      :period,
      :filling_date,
      :ccy,
      :conversion_rate,
      :yearly,
      :rounding,
      :revenue,
      :cogs,
      :gross_profit,
      :sales_marketing,
      :research_development,
      :general_administrative,
      :opex,
      :operating_income,
      :other_operating_income,
      :income_before_tax,
      :income_tax_expense,
      :net_income,
      :non_controlling_interest,
      :net_income_to_shareholders,
      :metadata
    ])
    |> Munchkin.Utils.Relations.cast_relations(
      [asset: Munchkin.Inventory.Asset, source: Munchkin.Inventory.AssetSource],
      attrs
    )
    |> validate_required([:period, :filling_date, :ccy])
  end
end
