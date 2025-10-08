defmodule Munchkin.Engine.Jkse.Stock do
  use Munchkin.Engine.Jkse.Engine

  def today do
    url = get_url(:stock_summary)

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
    url = get_url(:stock_summary, %{"date" => date})

    fetch(url, [])
    |> parse_data()
    |> then(fn data ->
      %{
        "data" => data,
        "date" => date
      }
    end)
  end

  def list do
    url = get_url(:stock_list)

    fetch(url, [])
    |> then(fn
      {:ok, data} -> {:ok, Enum.map(data, &translate_name/1)}
      err -> err
    end)
  end

  def suspensions do
    url = get_url(:stock_suspension)

    fetch(url, [])
    |> parse_suspension_data()
  end

  defp parse_data({:ok, %{"data" => stocks}}) do
    Enum.map(stocks, fn data ->
      Map.take(data, ["Open", "High", "Low", "Close", "Volume", "ForeignBuy", "ForeignSell"])
      |> Enum.map(fn {key, value} -> {String.downcase(key), parse_value(value)} end)
      |> then(fn d -> [{"ticker", Map.get(data, "StockCode")} | d] end)
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

  defp get_date(err), do: [err, nil]

  defp translate_name(data) do
    Enum.reduce(data, %{}, fn {key, val}, acc ->
      Map.put(acc, translate_key(key), String.trim(val))
    end)
  end

  defp translate_key(key) when key in ["NamaEmiten", "Company_Name"], do: "name"
  defp translate_key(key) when key in ["KodeEmiten", "Code"], do: "ticker"
  defp translate_key("Corporate_Secretary"), do: "drop"
  defp translate_key(key), do: String.downcase(key)

  defp parse_suspension_data({:ok, %{"contentBody" => body}}) do
    {:ok, last_update} = parse_last_update(body)

    Map.get(body, "value", "")
    |> LazyHTML.from_document()
    |> Access.get("tr")
    |> Enum.with_index()
    |> Enum.reduce([], fn
      {elem, 0}, acc -> initial_suspension_data(elem, acc)
      {elem, _index}, acc -> continuous_suspension_data(elem, acc)
    end)
    |> List.pop_at(0)
    |> then(fn {_popped, list} ->
      %{
        "last_update" => last_update,
        "data" =>
          Enum.map(
            list,
            &(Enum.reject(&1, fn {key, _val} -> key == "drop" || key == "no" end)
              |> Enum.into(%{}))
          )
      }
    end)
  end

  defp parse_suspension_data(err), do: err

  defp initial_suspension_data(elem, acc) do
    get_value_from_elem(elem)
    |> Enum.map(fn k ->
      String.replace(k, " ", "_")
      |> translate_key()
    end)
    |> then(fn d -> [d | acc] end)
  end

  defp continuous_suspension_data(elem, [item | last] = _acc) do
    keys =
      case item do
        i when is_map(i) -> Map.keys(i)
        _ -> item
      end

    values = get_value_from_elem(elem)

    Enum.zip_reduce(keys, values, %{}, fn a, b, acc ->
      Map.put(acc, a, b)
    end)
    |> then(fn a ->
      result = [a | last]
      [item | result]
    end)
  end

  defp get_value_from_elem(elem) do
    elem
    |> LazyHTML.query("td")
    |> Enum.map(&LazyHTML.text/1)
  end

  defp parse_last_update(body) do
    Map.get(body, "value", "")
    |> LazyHTML.from_document()
    |> LazyHTML.query("p")
    |> Enum.map(&LazyHTML.text/1)
    |> Enum.find(fn t ->
      String.downcase(t)
      |> String.contains?("information as of")
    end)
    |> then(fn
      t when is_bitstring(t) ->
        String.downcase(t)
        |> String.replace(["information", "as", "of"], "")
        |> String.trim()
        |> parse_date()

      _ ->
        Date.utc_today()
    end)
  end

  def fundamental(ticker, opts \\ []), do: Munchkin.Engine.Jkse.Fundamental.get(ticker, opts)
end
