defmodule Munchkin.Inventory.Fundamental.BalanceSheet do
  @derive [JSON.Encoder, Jason.Encoder]
  defstruct [
    :name,
    :cash_equivalent,
    :short_term_investment,
    :account_receivable,
    :inventories,
    :other_current_assets,
    :total_current_assets,
    :depreciation_and_amortization,
    :property_plant_equipment,
    :intangible_assets,
    :deferred_tax_assets,
    :long_term_investment,
    :long_term_receivables,
    :other_non_current_assets,
    :total_assets,
    :account_payable,
    :short_term_debt,
    :taxes_payable,
    :other_current_liabilities,
    :total_current_liabilities,
    :provisions,
    :long_term_debt,
    :deferred_tax_liabilities,
    :other_long_term_debt,
    :total_liabilities,
    :shareholders_equity_in_company,
    :non_controlling_interest,
    :total_equity,
    :total_liabilities_and_equity
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          cash_equivalent: Decimal.t(),
          short_term_investment: Decimal.t(),
          account_receivable: Decimal.t(),
          inventories: Decimal.t(),
          other_current_assets: Decimal.t(),
          total_current_assets: Decimal.t(),
          depreciation_and_amortization: Decimal.t(),
          property_plant_equipment: Decimal.t(),
          intangible_assets: Decimal.t(),
          deferred_tax_assets: Decimal.t(),
          long_term_investment: Decimal.t(),
          long_term_receivables: Decimal.t(),
          other_non_current_assets: Decimal.t(),
          total_assets: Decimal.t(),
          account_payable: Decimal.t(),
          short_term_debt: Decimal.t(),
          taxes_payable: Decimal.t(),
          other_current_liabilities: Decimal.t(),
          total_current_liabilities: Decimal.t(),
          provisions: Decimal.t(),
          long_term_debt: Decimal.t(),
          deferred_tax_liabilities: Decimal.t(),
          other_long_term_debt: Decimal.t(),
          total_liabilities: Decimal.t(),
          shareholders_equity_in_company: Decimal.t(),
          non_controlling_interest: Decimal.t(),
          total_equity: Decimal.t(),
          total_liabilities_and_equity: Decimal.t()
        }

  defimpl Inspect, for: __MODULE__ do
    def inspect(%_mod{name: name}, _opts) do
      "#BalanceSheet<ticker: #{name}, rest: ...>"
    end

    def inspect(_data, _opts) do
      "#BalanceSheet<data: ...>"
    end
  end

  defimpl Enumerable, for: __MODULE__ do
    def count(map) do
      {:ok, map_size(map)}
    end

    def member?(map, {key, value}) do
      {:ok, match?(%{^key => ^value}, map)}
    end

    def member?(_map, _other) do
      {:ok, false}
    end

    def slice(map) do
      size = map_size(map)
      {:ok, size, &Enumerable.List.slice(&1)}
    end

    def reduce(map, acc, fun) do
      Enumerable.List.reduce(:maps.to_list(map), acc, fun)
    end
  end
end
