defmodule Munchkin.Engine.Factset.Local do
  alias Munchkin.Engine.Factset.DB

  def get(ticker, opts \\ []) do
    DB.files()
    |> Enum.map(&read_from_stream(&1, ticker, opts))
    |> :lists.flatten()
    |> Enum.group_by(&Map.get(&1, "date"))
    |> Enum.reduce(%{}, fn {key, val}, acc ->
      Enum.reduce(val, %{}, &Map.merge(&2, &1))
      |> then(&Map.put(acc, Date.from_iso8601!(key), &1))
    end)
  end

  defp read_from_stream(file, ticker, _opts) do
    File.stream!(file)
    |> Stream.map(&Jason.decode!/1)
    |> Stream.filter(fn data ->
      case Map.get(data, "ticker_region") do
        ^ticker -> true
        _ -> false
      end
    end)
    |> Enum.to_list()
  end
end
