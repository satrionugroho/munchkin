defmodule MunchkinWeb.Analysis.General do
  use MunchkinWeb, :live_component

  alias Phoenix.LiveView.AsyncResult

  def update(assign, socket) do
    assign(socket, assign)
    |> assign(data: AsyncResult.loading())
    |> then(fn s ->
      ticker = s.assigns.ticker

      start_async(s, :get_data, fn ->
        get_data(ticker)
      end)
    end)
    |> ok()
  end

  def handle_async(:get_data, {:ok, data}, socket) do
    prev = socket.assigns.data

    assign(socket, data: AsyncResult.ok(prev, data))
    |> noreply()
  end

  defp get_data(ticker) do
    %{
      symbol: Munchkin.Inventory.transform_ticker(ticker, to: :trading_view, symbol: true),
      ticker: Munchkin.Inventory.transform_ticker(ticker, to: :trading_view, symbol: true)
    }
  end

  def render(assigns) do
    ~H"""
    <div>
      <.async_result :let={data} assign={@data}>
        <:loading>{gettext("Loading the chart")}</:loading>
        <:failed>{gettext("There was error during loading the chart")}</:failed>
        <div
          class="tradingview-widget-container mt-4"
          id="tradingview"
          phx-hook="TradingViewHook"
          data-symbol={data.symbol}
        >
          <div class="tradingview-widget-container__widget w-full h-120"></div>
          <div class="tradingview-widget-copyright hidden">
            <a
              href={"https://www.tradingview.com/symbols/#{data.ticker}/"}
              rel="noopener nofollow"
              target="_blank"
            >
              <span class="blue-text">{data.ticker} stock chart</span>
            </a>
            <span class="trademark"> by TradingView</span>
          </div>
        </div>
      </.async_result>
    </div>
    """
  end
end
