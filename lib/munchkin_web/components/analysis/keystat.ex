defmodule MunchkinWeb.Analysis.Keystat do
  use MunchkinWeb, :live_component

  def update(assigns, socket) do
    assign(socket, assigns)
    |> assign_new(:active_tab, fn -> "bs" end)
    |> assign_new(:timeframe, fn -> "yearly" end)
    |> assign_new(:currency_format, fn -> "simplified" end)
    |> assign_new(:ccyf, fn -> :short end)
    |> assign_async(:raw, fn ->
      case Munchkin.Cache.get(assigns.data_ref) do
        {:ok, data} -> {:ok, %{raw: data}}
        _ -> {:error, %{raw: []}}
      end
    end)
    |> tab_data()
    |> ok()
  end

  def handle_event("change-tab", %{"id" => id}, socket) do
    socket
    |> assign(:active_tab, id)
    |> tab_data()
    |> noreply()
  end

  def handle_event("change-frame", %{"timeframe" => frame, "format" => format}, socket) do
    socket
    |> assign(timeframe: frame, currency_format: format)
    |> assign_currency_format(format)
    |> tab_data()
    |> noreply()
  end

  defp assign_currency_format(socket, "standard") do
    assign(socket, :ccyf, :standard)
  end

  defp assign_currency_format(socket, _) do
    assign(socket, :ccyf, :short)
  end

  defp tab_data(socket) do
    case socket.assigns.active_tab do
      "bs" ->
        assign(socket,
          type: :balance_sheet,
          columns: MunchkinWeb.Helpers.BalanceSheetTransalation.displayed()
        )

      "is" ->
        assign(socket,
          type: :income_statement,
          columns: MunchkinWeb.Helpers.IncomeStatementTranslation.displayed()
        )

      _ ->
        assign(socket,
          type: :cashflow,
          columns: MunchkinWeb.Helpers.CashflowTranslation.displayed()
        )
    end
  end

  defp get_raw_data(ticker, start_year, end_year) do
    Range.new(start_year, end_year)
    |> Enum.into([])
    |> then(&Munchkin.Inventory.get_fundamental_data(ticker, &1))
    |> then(fn data -> {:ok, %{raw: data}} end)
  end

  def render(assigns) do
    ~H"""
    <div>
      <.card
        title={gettext("Fundamentals")}
        subtitle={gettext("quickly analyze a company's fundamental health")}
      >
        <div class="w-full">
          <div role="tablist" class="ml-10 tabs tabs-border">
            <a
              role="tab"
              class="tab tab-disabled mr-4"
            >&nbsp;</a>
            <a
              role="tab"
              phx-click="change-tab"
              phx-target={@myself}
              phx-value-id="bs"
              class={["tab", @active_tab == "bs" && "tab-active"]}
            >{gettext("Balance Sheet")}</a>
            <a
              role="tab"
              phx-click="change-tab"
              phx-target={@myself}
              phx-value-id="is"
              class={["tab", @active_tab == "is" && "tab-active"]}
            >{gettext("Income Statement")}</a>
            <a
              role="tab"
              phx-click="change-tab"
              phx-target={@myself}
              phx-value-id="cashflow"
              class={["tab", @active_tab == "cashflow" && "tab-active"]}
            >{gettext("Cashflow")}</a>
          </div>
        </div>
        <.async_result :let={raw} assign={@raw}>
          <div class="w-full mt-4 flex justify-between">
            <div>&nbsp;</div>
            <form phx-change="change-frame" class="flex" phx-target={@myself}>
              <.input
                type="select"
                key="timeframe"
                label={gettext("Timeframe")}
                value={@timeframe}
                name="timeframe"
                options={[{gettext("Quarterly"), "quarterly"}, {gettext("Yearly"), "yearly"}]}
              />
              <span class="ml-4">&nbsp;</span>

              <.input
                type="select"
                key="format"
                label={gettext("Currency Format")}
                value={@currency_format}
                name="format"
                options={[{gettext("Standard"), "standard"}, {gettext("Simplified"), "simplified"}]}
              />
            </form>
          </div>

          <.fundamental_table type={@type} data={raw} timeframe={@timeframe} format={@ccyf}>
            <:row :for={c <- @columns} key={c.key}>{c.label}</:row>
          </.fundamental_table>
        </.async_result>
      </.card>
    </div>
    """
  end
end
