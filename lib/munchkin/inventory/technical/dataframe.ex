defmodule Munchkin.Inventory.Technical.Dataframe do
  def shift(df, column, shift \\ 1) do
    keys = Explorer.DataFrame.names(df)

    case Enum.member?(keys, column) do
      true -> Explorer.Series.shift(df[column], shift)
      _ -> raise ArgumentError, message: "Dataframe not have specified column"
    end
  end

  def log_return(df, opts \\ []) do
    prev_close = shift(df, "close")

    Explorer.Series.divide(df["close"], prev_close)
    |> Explorer.Series.log()
    |> then(&Explorer.DataFrame.put(df, "return", &1))
    |> then(fn d ->
      case Keyword.get(opts, nil) do
        :stay -> d
        _ -> Explorer.DataFrame.drop_nil(d, ["return"])
      end
    end)
    |> then(fn d ->
      case Keyword.get(opts, :output) do
        :series -> d["return"]
        _ -> d
      end
    end)
  end

  def simple_return(df, opts \\ []) do
    prev_close = shift(df, "close")

    Explorer.Series.subtract(df["close"], prev_close)
    |> Explorer.Series.divide(prev_close)
    |> then(&Explorer.DataFrame.put(df, "return", &1))
    |> then(fn d ->
      case Keyword.get(opts, nil) do
        :stay -> d
        _ -> Explorer.DataFrame.drop_nil(d, ["return"])
      end
    end)
    |> then(fn d ->
      case Keyword.get(opts, :output) do
        :series -> d["return"]
        _ -> d
      end
    end)
  end
end
