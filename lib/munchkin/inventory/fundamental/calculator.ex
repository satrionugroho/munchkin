defmodule Munchkin.Inventory.Fundamental.Calculator do
  alias Munchkin.Inventory.Fundamental.{BalanceSheet, Schema}

  def wacc(%BalanceSheet{} = bs, beta, opts \\ []) do
    tax_rate = Keyword.get(opts, :tax_rate, 0.22)
    cost_of_debt = Keyword.get(opts, :cost_of_debt, 0.05)

    weight_equity = bs.total_equity / bs.total_liabilities_and_equity
    weight_debt = bs.total_liabilities / bs.total_liabilities_and_equity

    cost_of_equity = cost_of_equity(beta, opts)

    weight_equity
    |> Kernel.*(cost_of_equity)
    |> then(fn res ->
      weight_debt
      |> Kernel.*(cost_of_debt)
      |> Kernel.*(1 - tax_rate)
      |> then(&Kernel.+(res, &1))
    end)
  end

  def cost_of_equity(beta, opts \\ []) do
    market_risk = Keyword.get(opts, :market_risk, 0.05)
    risk_free_rate = Keyword.get(opts, :risk_free_rate, 0.04)

    beta
    |> Kernel.*(market_risk - risk_free_rate)
    |> Kernel.+(risk_free_rate)
  end

  def fcff_net_income(%Schema{} = fd1, %Schema{} = fd2, opts \\ []) do
    tax_rate = Keyword.get(opts, :tax_rate, 0.22)

    wo = change_in_working_capital(fd1.balance_sheet, fd2.balance_sheet)

    interest_expense =
      case fd1.income_statement.income_tax_expense do
        num when num > 0 -> num
        num -> Kernel.*(num, -1)
      end
      |> Kernel.*(1 - tax_rate)

    fd1.income_statement.net_income
    |> Kernel.+(fd1.income_statement.depreciation_and_amortization)
    |> Kernel.-(fd1.cashflow.capex)
    |> Kernel.-(wo)
    |> Kernel.+(interest_expense)
  end

  def fcff_cfo(%Schema{} = fd1, opts \\ []) do
    tax_rate = Keyword.get(opts, :tax_rate, 0.22)

    interest_expense =
      case fd1.income_statement.income_tax_expense do
        num when num > 0 -> num
        num -> Kernel.*(num, -1)
      end
      |> Kernel.*(1 - tax_rate)

    fd1.cashflow.net_cash_operating
    |> Kernel.+(interest_expense)
    |> Kernel.-(fd1.cashflow.capex)
  end

  def fcff_nopat(%Schema{} = fd1, %Schema{} = fd2) do
    wo = change_in_working_capital(fd1.balance_sheet, fd2.balance_sheet)

    fd1.cashflow.net_cash_operating
    |> Kernel.+(fd1.income_statement.depreciation_and_amortization)
    |> Kernel.-(fd1.cashflow.capex)
    |> Kernel.-(wo)
  end

  def fcfe_net_income(%Schema{} = fd1, %Schema{} = fd2) do
    wo = change_in_working_capital(fd1.balance_sheet, fd2.balance_sheet)

    fcfe_cfo(fd1)
    |> Kernel.+(fd1.income_statement.depreciation_and_amortization)
    |> Kernel.-(wo)
  end

  def fcfe_cfo(%Schema{} = fd1) do
    fd1.cashflow.net_cash_operating
    |> Kernel.-(fd1.cashflow.capex)
    |> Kernel.+(fd1.cashflow.net_cash_financing)
  end

  defp change_in_working_capital(%BalanceSheet{} = bs1, %BalanceSheet{} = bs2) do
    bs1.total_current_assets
    |> Kernel.-(bs1.total_liabilities)
    |> then(fn v ->
      bs2.total_current_assets
      |> Kernel.-(bs2.total_liabilities)
      |> then(&Kernel.-(v, &1))
    end)
  end

  def net_debt(%Schema{} = fd) do
    fd.balance_sheet.short_term_debt
    |> Kernel.+(fd.balance_sheet.long_term_debt)
    |> Kernel.-(fd.balance_sheet.cash_equivalent)
  end

  def dcf(initial, net_debt, shares, opts \\ []) do
    period = Keyword.get(opts, :period, 5)
    growth_rate = Keyword.get(opts, :growth_rate, 0.08)
    decay_rate = Keyword.get(opts, :decay_rate, 0.2)
    discount_rate = Keyword.get(opts, :discount_rate, 0.06)
    terminal_growth_rate = Keyword.get(opts, :terminal_growth_rate, 0.025)

    projections = generate_projections(initial, period, growth_rate, decay_rate)

    terminal_val =
      List.last(projections)
      |> Map.get(:value)
      |> calculate_terminal_value(terminal_growth_rate, discount_rate, period)

    sum_pv = npv(projections, discount_rate)

    enterprise_value = terminal_val + sum_pv

    equity_value = enterprise_value - net_debt
    share_price = equity_value / shares

    %{
      initial: initial,
      projections: projections,
      terminal_value: terminal_val,
      enterprise_value: enterprise_value,
      equity_value: equity_value,
      share_price: share_price
    }
  end

  defp generate_projections(init, period, growth_rate, decay_rate) do
    limit = Float.ceil(period / 2)

    Range.new(1, period)
    |> Enum.reduce([], fn
      year, acc when year <= limit ->
        growth = growth_rate * :math.pow(1 - decay_rate, 0)
        prev_val = Enum.find(acc, %{year: 0, value: init}, &(Map.get(&1, :year) == year - 1))
        current = (Map.get(prev_val, :value) * (1 + growth)) |> Float.round(4)
        [%{year: year, value: current, growth: growth} | acc]

      year, acc ->
        growth = growth_rate * :math.pow(1 - decay_rate, year - limit)
        prev_val = Enum.find(acc, %{year: 0, value: init}, &(Map.get(&1, :year) == year - 1))
        current = (Map.get(prev_val, :value) * (1 + growth)) |> Float.round(4)
        [%{year: year, value: current, growth: growth} | acc]
    end)
    |> Enum.sort_by(&Map.get(&1, :year))
  end

  defp calculate_terminal_value(value, terminal_growth, discount_rate, period) do
    value
    |> Kernel.*(1 + terminal_growth)
    |> Kernel./(discount_rate - terminal_growth)
    |> Kernel./(:math.pow(1 + discount_rate, period))
  end

  def ddm(cost_of_equity, dividend, opts \\ []) do
    period = Keyword.get(opts, :period, 5)
    decay_rate = Keyword.get(opts, :decay_rate, 0.06)
    growth_rate = Keyword.get(opts, :growth_rate, 0.08)
    sustainable_rate = Keyword.get(opts, :sustainable_growth_rate, 0.01)
    projections = generate_projections(dividend, period, growth_rate, decay_rate)

    terminal_val =
      List.last(projections)
      |> Map.get(:value)
      |> calculate_terminal_value(sustainable_rate, cost_of_equity, period)

    sum_pv = npv(projections, cost_of_equity)

    %{
      terminal_value: terminal_val,
      sum_pv: sum_pv,
      fair_val: Float.round(sum_pv + terminal_val, 2)
    }
  end

  defp npv(projections, discount_rate) do
    Enum.reduce(projections, 0, fn %{value: val, year: y}, acc ->
      val
      |> Kernel./(:math.pow(1 + discount_rate, y))
      |> then(&Kernel.+(&1, acc))
    end)
  end
end
