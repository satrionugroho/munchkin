defmodule Munchkin.Engine.Jkse.Fundamental.Type do
  def t(name), do: Map.get(data(), name)

  def k(name) do
    Enum.reduce(data(), [], fn
      {key, val}, acc when val == name -> [key | acc]
      _, acc -> acc
    end)
  end

  def available_types, do: Map.keys(data())
  def available_fundamentals, do: Map.values(data()) |> Enum.uniq()

  def balance_sheets, do: filter_keys("balance_sheet")
  def income_statements, do: filter_keys("income_statement")
  def cashflows, do: filter_keys("cashflow")
  def general_information, do: filter_keys("general_information")

  def periods do
    ~w(q1 q2 q3 fy)
  end

  defp filter_keys(type) do
    Enum.filter(data(), fn {_k, v} -> v == type end)
    |> Enum.map(fn {k, _v} -> k end)
  end

  defp data do
    %{
      "1000000" => "general_information",
      "1210000" => "balance_sheet",
      "2210000" => "balance_sheet",
      "3210000" => "balance_sheet",
      "4220000" => "balance_sheet",
      "5220000" => "balance_sheet",
      "6220000" => "balance_sheet",
      "8220000" => "balance_sheet",
      "1311000" => "income_statement",
      "2311000" => "income_statement",
      "3311000" => "income_statement",
      "4322000" => "income_statement",
      "5311000" => "income_statement",
      "6312000" => "income_statement",
      "8322000" => "income_statement",
      "1510000" => "cashflow",
      "2510000" => "cashflow",
      "3510000" => "cashflow",
      "4510000" => "cashflow",
      "5510000" => "cashflow",
      "6510000" => "cashflow",
      "8510000" => "cashflow"
    }
  end
end
