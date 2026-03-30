defmodule Munchkin.Inventory.Technical do
  def calculate(ticker, opts \\ []) do
    with market <- Keyword.get(opts, :market, "COMPOSITE"),
         query_params <- [output: :map, fields: [:open, :high, :low, :close, :date, :volume]],
         oneYear <- Keyword.get(opts, :limit, 252),
         query_opts <- Keyword.put(query_params, :limit, oneYear),
         stock_data <- Munchkin.Inventory.get_asset_trade_history(ticker, query_opts),
         market_data <- Munchkin.Inventory.get_asset_trade_history(market, query_opts),
         stock_df <- Explorer.DataFrame.new(stock_data),
         market_df <- Explorer.DataFrame.new(market_data),
         dataframe <- calculate_returns(stock_df, market_df, opts),
         stats <-
           Munchkin.Inventory.Technical.Stats.linregress(
             Explorer.Series.to_list(dataframe["market_return"]),
             Explorer.Series.to_list(dataframe["stock_return"])
           ),
         beta <-
           Munchkin.Inventory.Technical.Stats.beta_covariance(
             Explorer.Series.to_list(dataframe["market_return"]),
             Explorer.Series.to_list(dataframe["stock_return"])
           ),
         mom <- Munchkin.Inventory.Technical.Momentum.momentum(stock_df) do
      %{
        "stats" => stats,
        "mom" => mom,
        "beta" => beta,
        "df" => dataframe
      }
    end
  end

  defp calculate_returns(stock_df, market_df, opts) do
    case Keyword.get(opts, :returns) do
      :simple ->
        [
          Munchkin.Inventory.Technical.Dataframe.simple_return(stock_df),
          Munchkin.Inventory.Technical.Dataframe.simple_return(market_df)
        ]

      _ ->
        [
          Munchkin.Inventory.Technical.Dataframe.log_return(stock_df),
          Munchkin.Inventory.Technical.Dataframe.log_return(market_df)
        ]
    end
    |> then(fn [dfA, dfB] ->
      Explorer.DataFrame.join(dfA, dfB, how: :inner, on: "date")
      |> Explorer.DataFrame.rename(
        open: "stock_open",
        high: "stock_high",
        low: "stock_low",
        close: "stock_close",
        volume: "stock_volume",
        return: "stock_return",
        open_right: "market_open",
        high_right: "market_high",
        low_right: "market_low",
        close_right: "market_close",
        volume_right: "market_volume",
        return_right: "market_return"
      )
    end)
  end
end
