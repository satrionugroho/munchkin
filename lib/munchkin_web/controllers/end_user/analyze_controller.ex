defmodule MunchkinWeb.EndUser.AnalyzeController do
  alias Munchkin.Inventory
  use MunchkinWeb, :controller

  def index(conn, _params) do
    form =
      %Munchkin.Inventory.Asset{}
      |> Munchkin.Inventory.Asset.changeset(%{})
      |> Phoenix.Component.to_form()

    render(conn, :index, form: form)
  end

  def show(conn, %{"id" => id}) do
    case String.contains?(id, ".") do
      false ->
        ticker = Inventory.transform_ticker(id)
        redirect(conn, to: "/analyze/#{ticker}")

      _ ->
        render_show(conn, id)
    end
  end

  defp render_show(conn, id) do
    with ticker <- Inventory.transform_ticker(id),
         tv_ticker <- Inventory.transform_ticker(id, to: :trading_view),
         tv_symbol <- Inventory.transform_ticker(id, to: :trading_view, symbol: true) do
      render(conn, :show, ticker: ticker, tv_ticker: tv_ticker, tv_symbol: tv_symbol)
    end
  end
end
