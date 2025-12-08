defmodule MunchkinWeb.API.V1.AnalyzeJSON do
  def render("index.json", %{data: data}) do
    %{
      data: Enum.map(data, &standardize_data/1),
      messages: [],
      actions: "get analized data"
    }
  end

  defp standardize_data(data) do
    data
    |> Map.put(:cashflow, normalize(data.cashflow))
    |> Map.put(:balance_sheet, normalize(data.balance_sheet))
    |> Map.put(:income_statement, normalize(data.income_statement))
  end

  defp normalize(data) do
    Enum.reduce(data, %{}, fn
      {k, v}, acc when is_number(v) ->
        Map.put(acc, k, abs(v))

      {k, v}, acc ->
        Map.put(acc, k, v)
    end)
  end
end
