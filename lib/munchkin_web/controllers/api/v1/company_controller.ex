defmodule MunchkinWeb.API.V1.CompanyController do
  use MunchkinWeb, :controller

  def show(conn, %{"ticker" => ticker}) do
    with company when not is_nil(company) <- Munchkin.Inventory.get_asset(ticker) do
      render(conn, :show, company: company)
    else
      _ ->
        render(conn, :not_found,
          messages: [
            gettext("cannot get a company with ticker=%{ticker}", ticker: inspect(ticker))
          ],
          actions: "get company"
        )
    end
  end

  def eod(conn, %{"ticker" => ticker}) do
    with [_ | _] = trades <- Munchkin.Inventory.get_asset_trade_history(ticker) do
      render(conn, :eod, trades: trades)
    else
      _ ->
        render(conn, :not_found,
          messages: [
            gettext("cannot get trade history with ticker=%{ticker}", ticker: inspect(ticker))
          ],
          actions: "get trade history"
        )
    end
  end

  def last_trade(conn, %{"ticker" => ticker}) do
    with %Munchkin.Inventory.TradeHistory{} = trade <-
           Munchkin.Inventory.get_last_trade_history(ticker) do
      render(conn, :last_trade, trade: trade)
    else
      _ ->
        render(conn, :not_found,
          messages: [
            gettext("cannot get last trade history with ticker=%{ticker}",
              ticker: inspect(ticker)
            )
          ],
          actions: "get last trade history"
        )
    end
  end

  def last_fundamental_year(conn, %{"ticker" => ticker} = opts) do
    with period_type <- Map.get(opts, "period", "fy"),
         data <- Munchkin.Inventory.last_available_fundamental_data(ticker, period_type),
         market_capitals <- Munchkin.Inventory.market_capital(ticker) do
      render(conn, :last_fundamental_year, data: data, market_capitals: market_capitals)
    end
  end
end
