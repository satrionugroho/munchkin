defmodule Munchkin.Inventory.Fundamental.BalanceSheet do
  defstruct [
    :name,
    :period,
    :cash_equivalent,
    :short_term_investment,
    :account_receivable,
    :inventories,
    :other_current_assets,
    :total_current_assets,
    :property_plant_equipment,
    :intangible_assets,
    :other_non_current_assets,
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
    :total_liabilities_and_equity
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          period: String.t(),
          cash_equivalent: Decimal.t(),
          short_term_investment: Decimal.t(),
          account_receivable: Decimal.t(),
          inventories: Decimal.t(),
          other_current_assets: Decimal.t(),
          total_current_assets: Decimal.t(),
          property_plant_equipment: Decimal.t(),
          intangible_assets: Decimal.t(),
          other_non_current_assets: Decimal.t(),
          total_assets: Decimal.t(),
          account_payable: Decimal.t(),
          short_term_debt: Decimal.t(),
          other_current_liabilities: Decimal.t(),
          total_current_liabilities: Decimal.t(),
          long_term_debt: Decimal.t(),
          other_long_term_debt: Decimal.t(),
          total_liabilities: Decimal.t(),
          shareholders_equity_in_company: Decimal.t(),
          non_controlling_interest: Decimal.t(),
          total_equity: Decimal.t(),
          total_liabilities_and_equity: Decimal.t()
        }

  defimpl Inspect, for: __MODULE__ do
    def inspect(%_mod{name: name, period: period}, _opts) do
      "#BalanceSheet<ticker: #{name}, period: #{period}, rest: ...>"
    end
  end

  defimpl Jason.Encoder, for: __MODULE__ do
    def encode(value, opts) do
      Map.from_struct(value)
      |> Jason.Encode.map(opts)
    end
  end
end
