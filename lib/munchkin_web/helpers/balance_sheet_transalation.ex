defmodule MunchkinWeb.Helpers.BalanceSheetTransalation do
  use Gettext, backend: MunchkinWeb.Gettext

  def items do
    [
      %{key: :name, label: gettext("Name"), id: 1},
      %{key: :cash_equivalent, label: gettext("Cash & Cash Equivalent"), id: 2},
      %{key: :short_term_investment, label: gettext("Short-term Investment"), id: 3},
      %{key: :account_receivable, label: gettext("Account Receivable"), id: 4},
      %{key: :inventories, label: gettext("Inventories"), id: 5},
      %{key: :other_current_assets, label: gettext("Other Current Assets"), id: 6},
      %{key: :total_current_assets, label: gettext("Total Current Assets"), id: 7},
      %{
        key: :depreciation_and_amortization,
        label: gettext("Depreciation & Amortization"),
        id: 8
      },
      %{key: :property_plant_equipment, label: gettext("Property, Plant and Equipment"), id: 9},
      %{key: :intangible_assets, label: gettext("Intangible Assets"), id: 10},
      %{key: :deferred_tax_assets, label: gettext("Deferred Tax Assets"), id: 11},
      %{key: :long_term_investment, label: gettext("Long-Term Investment"), id: 12},
      %{key: :long_term_receivables, label: gettext("Long-Term Receivables"), id: 13},
      %{key: :other_non_current_assets, label: gettext("Other Non-current Assets"), id: 14},
      %{key: :total_assets, label: gettext("Total Assets"), id: 15},
      %{key: :account_payable, label: gettext("Account Payables"), id: 16},
      %{key: :short_term_debt, label: gettext("Short-term Debt"), id: 17},
      %{key: :taxes_payable, label: gettext("Taxes Payable"), id: 18},
      %{key: :other_current_liabilities, label: gettext("Other Current Liabilities"), id: 19},
      %{key: :total_current_liabilities, label: gettext("Total Current Liabilities"), id: 20},
      %{key: :provisions, label: gettext("Provisions"), id: 21},
      %{key: :long_term_debt, label: gettext("Long-term Debt"), id: 22},
      %{key: :deferred_tax_liabilities, label: gettext("Deferred Tax Liabilities"), id: 23},
      %{key: :other_long_term_debt, label: gettext("Other Long-term Debt"), id: 24},
      %{key: :total_liabilities, label: gettext("Total Liabilities"), id: 25},
      %{
        key: :shareholders_equity_in_company,
        label: gettext("Shareholders Equitey in Company"),
        id: 26
      },
      %{key: :non_controlling_interest, label: gettext("Non-controlling Interest"), id: 27},
      %{key: :total_equity, label: gettext("Total Equity"), id: 28},
      %{key: :total_liabilities_and_equity, label: gettext("Total Liabilities & Equity"), id: 29}
    ]
  end

  def displayed do
    items()
    |> Enum.reject(fn %{id: id} ->
      id in [1]
    end)
  end
end
