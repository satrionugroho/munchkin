defmodule MunchkinWeb.EndUser.HomeController do
  use MunchkinWeb, :controller

  def index(conn, _params) do
    with user <- get_current_user(conn),
         [_ | _] = overview_tickers <- user.personalization.overview_tickers,
         ticker_symbols <- Enum.join(overview_tickers, ",") do
      render(conn, :index, ticker_symbols: ticker_symbols)
    end
  end
end
