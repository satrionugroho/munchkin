defmodule MunchkinWeb.Helpers.CashflowTranslation do
  use Gettext, backend: MunchkinWeb.Gettext

  def items do
    [
      %{key: :name, label: gettext("Name"), id: 1},
      %{key: :net_income, label: gettext("Net Income"), id: 2},
      %{key: :stock_based_expense, label: gettext("Stock Based Expense"), id: 3},
      %{key: :operating_expense, label: gettext("Operating Expense"), id: 4},
      %{
        key: :depreciation_and_amortization,
        label: gettext("Depreciation & Amortization"),
        id: 5
      },
      %{key: :net_cash_operating, label: gettext("Net Cash Operating"), id: 6},
      %{key: :investing_purchases, label: gettext("Investing Purchases"), id: 7},
      %{key: :business_acquisition, label: gettext("Business & Acquisition"), id: 8},
      %{key: :fixed_assets, label: gettext("Fixed Assets"), id: 9},
      %{key: :capex, label: gettext("Capital Expenditure"), id: 10},
      %{key: :other_investing_activities, label: gettext("Other Investing Activities"), id: 11},
      %{key: :net_cash_investing, label: gettext("Net-cash Investing"), id: 12},
      %{key: :issuance_stocks, label: gettext("Issuance Stocks"), id: 13},
      %{key: :dividends_paid, label: gettext("Dividends Paid"), id: 14},
      %{key: :repurchase_stocks, label: gettext("Repurchase Stocks"), id: 15},
      %{key: :other_financing_activities, label: gettext("Other Financing Activities"), id: 16},
      %{key: :net_cash_financing, label: gettext("Net-cash Financing"), id: 17},
      %{key: :exchange_rate, label: gettext("Exchange Rate"), id: 18},
      %{key: :change_in_cash, label: gettext("Change in cash"), id: 19},
      %{key: :cash_in_beginning_period, label: gettext("Cash in Beginning Period"), id: 20},
      %{key: :cash_in_end_period, label: gettext("Cash in End Period"), id: 21}
    ]
  end

  def displayed do
    items()
    |> Enum.reject(fn %{id: id} ->
      id in [1]
    end)
  end
end
