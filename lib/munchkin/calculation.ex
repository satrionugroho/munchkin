defmodule Munchkin.Calculation do
  def dataframe(data) when is_list(data) do
    Explorer.DataFrame.new(data)
    |> Explorer.DataFrame.sort_with(&[desc: &1["date"]])
  end

  def shift(dataframe, column, shifter \\ 1) do
    keys = Explorer.DataFrame.names(dataframe)

    case Enum.member?(keys, column) do
      true -> Explorer.Series.shift(dataframe[column], shifter)
      _ -> raise ArgumentError, message: "dataframe cannot be shifted"
    end
  end

  def log_return(df) do
    prev_close = shift(df, "close")

    Explorer.Series.divide(df["close"], prev_close)
    |> Explorer.Series.log()
    |> then(&Explorer.DataFrame.put(df, "log_return", &1))
  end

  def simple_return(df) do
    prev_close = shift(df, "close")

    Explorer.Series.subtract(df["close"], prev_close)
    |> Explorer.Series.divide(prev_close)
    |> then(&Explorer.DataFrame.put(df, "simple_return", &1))
  end

  def beta_calculation(df1, df2, column \\ "log_return")

  def beta_calculation(df1, df2, type) when type in ["log_return", "simple_return"] do
    index_df = Munchkin.Calculation.log_return(df2)
    stock_df = Munchkin.Calculation.log_return(df1)

    index_len = Explorer.Series.count(index_df[type])
    stock_len = Explorer.Series.count(stock_df[type])

    [cov, var] = case index_len do
      ^stock_len -> 
        [Explorer.Series.covariance(stock_df[type], index_df[type]), Explorer.Series.variance(index_df[type])]

      len when len > stock_len ->
        s1 = Explorer.Series.slice(stock_df[type], 0..stock_len)
        s2 = Explorer.Series.slice(index_df[type], 0..stock_len)

        [Explorer.Series.covariance(s1, s2), Explorer.Series.variance(s2)]

      _ -> 
        s1 = Explorer.Series.slice(stock_df[type], 0..index_len)
        s2 = Explorer.Series.slice(index_df[type], 0..index_len)

        [Explorer.Series.covariance(s1, s2), Explorer.Series.variance(s2)]
    end

    Kernel./(cov, var)
  end

  def beta_calculation(_df1, _df2, _), do: 0.5
end
