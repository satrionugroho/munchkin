defmodule Munchkin.Engine.Jkse.Index do
  use Munchkin.Engine.Jkse.Engine

  def today do
    url = get_url(:index_summary)

    fetch(url, [])
    |> get_date()
    |> then(fn [data, date] ->
      %{
        "data" => data,
        "date" => date
      }
    end)
  end

  def daily(date) when is_bitstring(date) do
    case Date.from_iso8601(date) do
      {:ok, d} -> daily(d)
      err -> err
    end
  end

  def daily(date) when is_map(date) do
    url = get_url(:index_summary, %{"date" => date})

    fetch(url, [])
    |> parse_data()
    |> then(fn data ->
      %{
        "data" => data,
        "date" => date
      }
    end)
  end

  defp parse_data({:ok, %{"data" => indices}}) do
    Enum.map(indices, fn data ->
      Map.take(data, ["Previous", "Highest", "Lowest", "Close", "Volume"])
      |> Enum.map(fn {key, value} -> {translate(key), parse_value(value)} end)
      |> then(fn d -> [{"ticker", Map.get(data, "IndexCode")} | d] end)
      |> Enum.into(%{})
    end)
  end

  defp parse_data(err), do: err

  defp parse_value(numeric_data) do
    Float.to_string(numeric_data)
    |> Decimal.new()
  end

  defp get_date({:ok, %{"data" => stocks}} = result) do
    date = List.first(stocks) |> Map.get("Date") |> string_to_date()
    data = parse_data(result)
    [data, date]
  end

  defp translate(key) do
    Map.get(dict(), key, "drop")
  end

  defp dict do
    %{
      "Close" => "close",
      "Previous" => "open",
      "Highest" => "high",
      "Lowest" => "low",
      "Volume" => "volume"
    }
  end
end
