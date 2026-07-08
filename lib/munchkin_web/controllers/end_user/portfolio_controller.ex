defmodule MunchkinWeb.EndUser.PortfolioController do
  use MunchkinWeb, :controller

  def index(conn, _params) do
    with current_user <- get_current_user(conn),
         {:ok, portfolio} <- Munchkin.Inventory.user_portfolio(current_user),
         total_invested <- get_total_invested(portfolio),
         unrealized_pnl <- get_unrealized_pnl(portfolio) do
      render(conn, :index, total_invested: total_invested, unrealized_pnl: unrealized_pnl)
    end
  end

  defp get_total_invested(portfolio) do
    Enum.reduce(portfolio, 0, fn {_, p}, acc ->
      Map.get(p, :asset_value, 0)
      |> Decimal.add(acc)
    end)
    |> Decimal.to_float()
    |> Munchkin.Cldr.Number.to_string!(currency: :idr, format: :short)
  end

  defp get_unrealized_pnl(portfolio) do
    Enum.reduce(portfolio, 0, fn {_, p}, acc ->
      Map.get(p, :estimated_pnl, 0)
      |> Decimal.add(acc)
    end)
    |> Decimal.to_float()
    |> Munchkin.Cldr.Number.to_string!(currency: :idr, format: :short)
  end
end
