defmodule MunchkinWeb.Helpers.IncomeStatementTranslation do
  use Gettext, backend: MunchkinWeb.Gettext

  def items do
    [
      %{key: :name, label: gettext("Name"), id: 1},
      %{key: :revenue, label: gettext("Revenue"), id: 2},
      %{key: :cogs, label: gettext("Cost of Good Sold"), id: 3},
      %{key: :gross_profit, label: gettext("Gross Profit"), id: 4},
      %{key: :sales_marketing, label: gettext("Sales Marketing"), id: 5},
      %{key: :research_development, label: gettext("Research & Development"), id: 6},
      %{key: :general_administrative, label: gettext("General Administrative"), id: 7},
      %{
        key: :depreciation_and_amortization,
        label: gettext("Depreciation & Amortization"),
        id: 8
      },
      %{key: :other_operating_income, label: gettext("Other Operating Income"), id: 9},
      %{key: :other_operating_expense, label: gettext("Other Operating Expense"), id: 10},
      %{key: :operating_income, label: gettext("Operating Income"), id: 11},
      %{key: :non_operating_income, label: gettext("Non-operating Income"), id: 12},
      %{key: :non_operating_expense, label: gettext("Non-operating Expense"), id: 13},
      %{key: :income_before_tax, label: gettext("Income Before Tax"), id: 14},
      %{key: :income_tax_expense, label: gettext("Income Tax Expense"), id: 15},
      %{key: :other_comprehensive_income, label: gettext("Other Comprehensive Income"), id: 16},
      %{key: :net_income, label: gettext("Net Income"), id: 17},
      %{key: :non_controlling_interest, label: gettext("Non-controlling Interest"), id: 18},
      %{key: :net_income_to_shareholders, label: gettext("Net Income to Shareholders"), id: 19},
      %{key: :basic_eps, label: gettext("Basic EPS"), id: 20},
      %{key: :basic_discontinued_eps, label: gettext("Basic Discontinued EPS"), id: 21},
      %{key: :diluted_eps, label: gettext("Diluted EPS"), id: 22},
      %{key: :diluted_discontinued_eps, label: gettext("Diluted Discontinued EPS"), id: 23}
    ]
  end

  def displayed do
    items()
    |> Enum.reject(fn %{id: id} ->
      id in [1]
    end)
  end
end
