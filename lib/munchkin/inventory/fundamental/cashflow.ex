defmodule Munchkin.Inventory.Fundamental.Cashflow do
  @derive [JSON.Encoder, Jason.Encoder]
  defstruct [
    :name,
    :net_income,
    :stock_based_expense,
    :operating_expense,
    :depreciation_and_amortization,
    :net_cash_operating,
    :investing_purchases,
    :business_acquisition,
    :fixed_assets,
    :capex,
    :other_investing_activities,
    :net_cash_investing,
    :issuance_stocks,
    :dividends_paid,
    :repurchase_stocks,
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
          investing_purchases: Decimal.t(),
          business_acquisition: Decimal.t(),
          fixed_assets: Decimal.t(),
          capex: Decimal.t(),
          other_investing_activities: Decimal.t(),
          net_cash_investing: Decimal.t(),
          issuance_stocks: Decimal.t(),
          dividends_paid: Decimal.t(),
          repurchase_stocks: Decimal.t(),
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
