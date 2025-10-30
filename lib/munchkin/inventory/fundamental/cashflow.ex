defmodule Munchkin.Inventory.Fundamental.Cashflow do
  @derive JSON.Encoder
  @derive Jason.Encoder
  defstruct [
    :name,
    :net_income,
    :stock_based_expense,
    :operating_expense,
    :depreciation_and_amortization,
    :net_cash_operating,
    :investing_income,
    :capex,
    :other_investing_activities,
    :net_cash_investing,
    :financing_income,
    :financing_expense,
    :other_financing_activities,
    :net_cash_financing,
    :exchange_rate,
    :chane_in_cash,
    :cash_in_beginning_period,
    :cash_in_end_period
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          net_income: Decimal.t(),
          stock_based_expense: Decimal.t(),
          operating_expense: Decimal.t(),
          depreciation_and_amortization: Decimal.t(),
          net_cash_operating: Decimal.t(),
          investing_income: Decimal.t(),
          capex: Decimal.t(),
          other_investing_activities: Decimal.t(),
          net_cash_investing: Decimal.t(),
          financing_income: Decimal.t(),
          financing_expense: Decimal.t(),
          other_financing_activities: Decimal.t(),
          net_cash_financing: Decimal.t(),
          exchange_rate: Decimal.t(),
          chane_in_cash: Decimal.t(),
          cash_in_beginning_period: Decimal.t(),
          cash_in_end_period: Decimal.t()
        }

  defimpl Inspect, for: __MODULE__ do
    def inspect(%_mod{name: name}, _opts) do
      "#Cashflow<ticker: #{name}, rest: ...>"
    end

    def inspect(_data, _opts) do
      "#Cashflow<data: ...>"
    end
  end
end
