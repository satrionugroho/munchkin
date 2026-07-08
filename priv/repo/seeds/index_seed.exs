defmodule IndexMigrator do
  def get_index_data() do
    now = DateTime.utc_now() |> DateTime.shift(day: -2)
    Enum.map(1..150, fn i -> 
      DateTime.shift(now, day: -i)
      |> DateTime.to_date()
      |> Date.to_string()
      |> get_index_eod()
    end)
  end

  defp get_index_eod(date_string) do
    Munchkin.Engine.Jkse.Index.daily(date_string)
      |> case do
        %{"data" => [_ | _] = data} -> insert_data_to_db(data, date_string)
        err -> 
        :logger.error("cannot find transaction at #{date_string}")
        err
      end
  end

  defp insert_data_to_db(data, date_string) do
    Enum.map(data, fn %{"ticker" => ticker} = d -> 
      _ = find_or_create_asset(d)
      Munchkin.Inventory.add_trade_data(%{"ticker" => ticker, "trades" => [Map.put(d, "date", date_string)]})
    end)
  end

  defp find_or_create_asset(%{"ticker" => ticker}) do
    case Munchkin.Inventory.get_index(ticker) do
      nil -> create_asset(ticker)
      asset -> {:ok, asset}
    end
  end

  defp create_asset(ticker) do
    Munchkin.Inventory.create_asset(%{"exchange" => "JK", "ticker" => ticker, "name" => ticker, "type_id" => "index"})
    |> case do
      {:ok, data} -> Map.get(data, :asset) |> then(fn a -> {:ok, a} end)
      err -> err
    end
  end
end

IndexMigrator.get_index_data()
