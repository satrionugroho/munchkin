defmodule MunchkinWeb.EndUser.TransactionController do
  use MunchkinWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end

  def search(conn, %{"q" => q, "transaction_type" => "sell"}) do
    with current_user <- get_current_user(conn),
         {:ok, raw_data} <- Munchkin.Inventory.user_portfolio(current_user),
         asset_data <- get_asset_data(raw_data, q),
         data <- parse_data(asset_data) do
      json(conn, data)
    end
  end

  def search(conn, %{"q" => q}) do
    with raw_data <- Munchkin.Inventory.search_ticker(q),
         data <- parse_data(raw_data) do
      json(conn, data)
    end
  end

  def find(conn, %{"q" => q}) do
    with raw_data <- Munchkin.Inventory.search_ticker(q),
         data <- parse_found_data(raw_data) do
      json(conn, data)
    end
  end

  def get_asset_data(portfolio, query) do
    Map.keys(portfolio)
    |> Munchkin.Inventory.get_multiple_assets(keyword: query)
    |> Enum.map(fn asset ->
      ticker = List.first(asset.tickers)
      %{name: asset.name, ticker: ticker.ticker, exchange: ticker.exchange, id: asset.id}
    end)
  end

  defp parse_found_data(data) when length(data) > 0 do
    %{
      status: 200,
      data: Enum.map(data, &standardize_found_data/1)
    }
  end

  defp parse_found_data(_data), do: parse_data(nil)

  defp parse_data(data) when length(data) > 0 do
    %{
      status: 200,
      data: Enum.map(data, &standardize_data/1)
    }
  end

  defp parse_data(_) do
    %{
      status: 404,
      data: []
    }
  end

  defp standardize_data(data) do
    %{
      label: "#{Map.get(data, :name)} (#{Map.get(data, :ticker)}-#{Map.get(data, :exchange)})",
      value: Map.get(data, :id)
    }
  end

  defp standardize_found_data(data) do
    %{
      label: "#{Map.get(data, :name)} (#{Map.get(data, :ticker)}-#{Map.get(data, :exchange)})",
      value: "#{Map.get(data, :ticker)}.#{Map.get(data, :exchange)}"
    }
  end
end
