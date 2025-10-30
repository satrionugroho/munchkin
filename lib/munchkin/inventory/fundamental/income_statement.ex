defmodule Munchkin.Inventory.Fundamental.IncomeStatement do
  @derive JSON.Encoder
  @derive Jason.Encoder
  defstruct [
    :name,
    :revenue,
    :cogs,
    :gross_profit,
    :sales_marketing,
    :research_development,
    :general_administrative,
    :depreciation_and_amortization,
    :other_operating_income,
    :other_operating_expense,
    :operating_income,
    :non_operating_income,
    :non_operating_expense,
    :income_before_tax,
    :income_tax_expense,
    :other_comprehensive_income,
    :net_income,
    :non_controlling_interest,
    :net_income_to_shareholders,
    :basic_eps,
    :basic_discontinued_eps,
    :diluted_eps,
    :diluted_discontinued_eps
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          revenue: Decimal.t(),
          cogs: Decimal.t(),
          gross_profit: Decimal.t(),
          sales_marketing: Decimal.t(),
          research_development: Decimal.t(),
          general_administrative: Decimal.t(),
          depreciation_and_amortization: Decimal.t(),
          other_operating_income: Decimal.t(),
          other_operating_expense: Decimal.t(),
          operating_income: Decimal.t(),
          non_operating_income: Decimal.t(),
          non_operating_expense: Decimal.t(),
          income_before_tax: Decimal.t(),
          income_tax_expense: Decimal.t(),
          other_comprehensive_income: Decimal.t(),
          net_income: Decimal.t(),
          non_controlling_interest: Decimal.t(),
          net_income_to_shareholders: Decimal.t(),
          basic_eps: Decimal.t(),
          basic_discontinued_eps: Decimal.t(),
          diluted_eps: Decimal.t(),
          diluted_discontinued_eps: Decimal.t()
        }

  defimpl Inspect, for: __MODULE__ do
    def inspect(%_mod{name: name}, _opts) do
      "#IncomeStatement<ticker: #{name}, rest: ...>"
    end

    def inspect(data, _opts) do
      name = Map.get(data, :name)
      "#IncomeStatement<ticker: #{name}, data: ...>"
    end
  end
end
