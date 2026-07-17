defmodule MunchkinWeb.EndUser.PortfolioLive do
  use MunchkinWeb, :live_view

  def mount(_, session, socket) do
    assign_user_id(session, socket)
    |> get_portfolio_async()
    |> user_personalization()
    |> default_assigns()
    |> ok()
  end

  def handle_event("open_detail", %{"id" => asset_id}, socket) do
    with current_user <- get_current_user(socket),
         {:ok, data} <- get_specific_transaction(current_user.id, asset_id),
         latest_close <- get_latest_asset_close(data) do
      assign(socket, modal_show: true, detail: data, latest_close: latest_close)
      |> noreply()
    else
      _ ->
        assign(socket, modal_show: false)
        |> put_flash(:error, gettext("cannot get portfolio detail"))
        |> noreply()
    end
  end

  def handle_event("close_detail", _, socket) do
    assign(socket, modal_show: false, transactions: [])
    |> noreply()
  end

  defp default_assigns(socket) do
    assign_new(socket, :modal_show, fn -> false end)
    |> assign_new(:detail, fn -> %{} end)
    |> assign_new(:latest_close, fn -> get_latest_asset_close(nil) end)
  end

  defp get_specific_transaction(user_id, asset_id) do
    with [trx | _] = transactions <-
           Munchkin.Inventory.get_user_specific_asset_transactions(user_id, asset_id),
         asset <-
           trx.asset do
      {:ok, %{transactions: transactions, asset: asset}}
    else
      _ -> {:error, %{transactions: [], asset: nil}}
    end
  end

  defp get_latest_asset_close(%{asset: %Munchkin.Inventory.Asset{} = asset}) do
    Munchkin.Inventory.get_last_trade_history(asset)
    |> case do
      m when is_map(m) ->
        %{
          close: Map.get(m, :close),
          date: Map.get(m, :date)
        }

      _ ->
        get_latest_asset_close(nil)
    end
  end

  defp get_latest_asset_close(_), do: %{close: 0, date: Date.utc_today()}

  defp get_portfolio_async(socket) do
    current_user = get_current_user(socket)

    assign_async(socket, [:portfolio, :stats], fn ->
      get_user_portfolio(current_user)
    end)
  end

  defp get_user_portfolio(user) do
    with {:ok, portfolio} <- Munchkin.Inventory.user_portfolio(user),
         [_ | _] = assets <- get_assets(portfolio),
         portfolio_data <- compose_portfolio(portfolio, assets),
         total_invested <- get_total_invested(portfolio),
         unrealized_pnl <- get_unrealized_pnl(portfolio),
         {:ok, realization} <- get_user_realization(user) do
      {:ok,
       %{
         portfolio: portfolio_data,
         stats: %{
           total_invested: total_invested,
           unrealized_pnl: unrealized_pnl,
           realization: realization
         }
       }}
    else
      _ ->
        {:error, %{portfolio: [], stats: %{total_invested: 0, unrealized_pnl: 0, realization: 0}}}
    end
  end

  defp get_assets(portfolio) do
    Map.keys(portfolio)
    |> Munchkin.Inventory.get_multiple_assets()
  end

  defp compose_portfolio(portfolio, assets) do
    Enum.map(portfolio, fn {key, data} ->
      asset = Enum.find(assets, &Kernel.==(&1.id, key))

      %{
        asset_id: key,
        asset_name: asset.name,
        value: Map.get(data, :asset_value) |> currency_format(),
        average_price: Map.get(data, :average_price) |> currency_format(type: :standard),
        current_value: Map.get(data, :current_value) |> currency_format(),
        estimated_pnl: Map.get(data, :estimated_pnl) |> Decimal.to_float(),
        quantity: Map.get(data, :quantity) |> Decimal.to_integer()
      }
    end)
  end

  defp get_total_invested(portfolio) do
    Enum.reduce(portfolio, 0, fn {_, p}, acc ->
      Map.get(p, :asset_value, 0)
      |> Decimal.add(acc)
    end)
    |> currency_format()
  end

  defp get_unrealized_pnl(portfolio) do
    Enum.reduce(portfolio, 0, fn {_, p}, acc ->
      Map.get(p, :estimated_pnl, 0)
      |> Decimal.add(acc)
    end)
    |> currency_format()
  end

  defp user_personalization(socket) do
    with current_user <- get_current_user(socket),
         [_ | _] = overview_tickers <- current_user.personalization.overview_tickers,
         ticker_symbols <- Enum.join(overview_tickers, ",") do
      assign(socket, :ticker_symbols, ticker_symbols)
    else
      _ ->
        assign(socket, :ticker_symbols, "")
    end
  end

  defp get_user_realization(user) do
    with realization_number <-
           Munchkin.Accounts.get_user_realizations(user, summary: true),
         realization <- currency_format(realization_number) do
      {:ok, realization}
    end
  end
end
