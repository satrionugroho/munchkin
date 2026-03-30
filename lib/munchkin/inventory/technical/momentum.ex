defmodule Munchkin.Inventory.Technical.Momentum do
  def roc(df, n) do
    prev_close = Munchkin.Inventory.Technical.Dataframe.shift(df, "close", n)

    Explorer.Series.divide(df["close"], prev_close)
    |> Explorer.Series.subtract(1)
    |> Explorer.Series.multiply(100)
  end

  def rsi(df, n \\ 14) do
    last_day_close =
      Munchkin.Inventory.Technical.Dataframe.shift(df, "close", 1)
      |> then(&Explorer.Series.subtract(df["close"], &1))

    up =
      Explorer.Series.transform(last_day_close, fn
        num when num < 0 -> 0
        num -> num
      end)

    down =
      Explorer.Series.transform(last_day_close, fn
        num when num > 0 -> 0
        num -> num
      end)
      |> Explorer.Series.abs()

    ma_up = Explorer.Series.window_mean(up, n)
    ma_down = Explorer.Series.window_mean(down, n)

    Explorer.Series.divide(ma_up, ma_down)
    |> Explorer.Series.add(1)
    |> then(&Explorer.Series.divide(100, &1))
    |> then(&Explorer.Series.subtract(100, &1))
  end

  def sma(df, n) do
    if !has_key?(df, "close") do
      raise ArgumentError, message: "Dataframe not have specified column"
    end

    Explorer.Series.window_mean(df["close"], n)
  end

  def ema(df, n) do
    if !has_key?(df, "close") do
      raise ArgumentError, message: "Dataframe not have specified column"
    end

    alpha = 2 / (n + 1)
    Explorer.Series.ewm_mean(df["close"], alpha: alpha, adjust: false)
  end

  def macd(df, opts \\ []) do
    short = Keyword.get(opts, :short, 12)
    long = Keyword.get(opts, :long, 26)
    signal = Keyword.get(opts, :signal, 9)

    short_ema = ema(df, short)
    long_ema = ema(df, long)
    macd = Explorer.Series.subtract(short_ema, long_ema)

    sign = Explorer.Series.ewm_mean(macd, alpha: 2 / (signal + 1), adjust: false)
    histo = Explorer.Series.subtract(macd, sign)

    Explorer.DataFrame.new(%{
      date: df["date"],
      macd: macd,
      signal: sign,
      histogram: histo
    })
  end

  def momentum(df, loopback \\ 5) do
    mo =
      Munchkin.Inventory.Technical.Dataframe.shift(df, "close", loopback)
      |> then(&Explorer.Series.subtract(df["close"], &1))

    Explorer.DataFrame.put(df, "Momentum", mo)
    |> Explorer.DataFrame.put("ROC", roc(df, loopback))
    |> Explorer.DataFrame.put("RSI", rsi(df, loopback))
    |> Explorer.DataFrame.put(
      "Log Return",
      Munchkin.Inventory.Technical.Dataframe.log_return(df, output: :series, nil: :stay)
    )
    |> Explorer.DataFrame.put(
      "Simple Return",
      Munchkin.Inventory.Technical.Dataframe.simple_return(df, output: :series, nil: :stay)
    )
    |> Explorer.DataFrame.put("SMA 20", sma(df, 20))
    |> Explorer.DataFrame.put("SMA 50", sma(df, 50))
    |> Explorer.DataFrame.put("EMA 20", ema(df, 20))
    |> Explorer.DataFrame.put("EMA 50", ema(df, 50))
    |> Explorer.DataFrame.join(macd(df), how: :inner, on: "date")
  end

  defp has_key?(df, [_h | _t] = columns) do
    key = Explorer.DataFrame.names(df)

    Enum.reduce(columns, true, fn k, acc ->
      Enum.member?(key, k)
      |> Kernel.and(acc)
    end)
  end

  defp has_key?(df, column), do: has_key?(df, [column])
end
