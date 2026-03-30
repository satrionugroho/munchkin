defmodule MunchkinWeb.API.V1.AnalyzeJSON do
  def render("index.json", %{data: data}) do
    %{
      data: Enum.map(data, &standardize_data/1),
      messages: [],
      actions: "get analized data"
    }
  end

  def render("marked.json", %{data: data}) do
    %{
      data: data,
      messages: [],
      actions: "marked analized data"
    }
  end

  def render("analize.json", %{data: data}) do
    %{
      data: analize_data(data),
      messages: [],
      actions: "get analized data"
    }
  end

  def render("summary.json", %{data: data}) when is_nil(data.results) do
    %{
      data: nil,
      messages: ["Initiate summary"],
      actions: "summary from analized data"
    }
  end

  def render("summary.json", %{data: data}) do
    %{
      data: data.results,
      messages: ["Initiate summary"],
      actions: "summary from analized data"
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

  defp analize_data(data) do
    result = Map.take(data, [:inserted_at, :updated_at, :user_id])

    summary_id =
      case data.summary_id do
        d when is_binary(d) -> Base.encode64(d)
        _ -> nil
      end

    analizers =
      Map.get(data, :analizers, %{})
      |> Map.get("analizers", %{})
      |> Enum.reduce(%{}, fn {k, v}, acc ->
        Map.put(acc, k, Map.keys(v))
      end)

    Map.put(result, :analizers, analizers)
    |> Map.put(:summary_id, summary_id)
  end
end
