defmodule MunchkinWeb.BuyTransactionComponent do
  use MunchkinWeb, :live_component

  alias Munchkin.Inventory.Transaction

  def mount(socket) do
    connected?(socket)
    |> then(fn
      true ->
        assign(socket, settlement_time: nil, available_assets: [])
        |> assign_market()

      _ ->
        assign(socket, settlement_time: nil, available_assets: [], available_market: [])
    end)
    |> ok()
  end

  def update(assigns, socket) do
    socket
    |> assign(:available_assets, Map.get(assigns, :available_assets))
    |> assign_new(:form, fn ->
      Munchkin.Inventory.change_transaction(%Transaction{})
      |> to_form()
    end)
    |> then(fn s -> {:ok, s} end)
  end

  def handle_event("handle_change", %{"settlement_time" => time}, socket)
      when not is_nil(time) and time != "" do
    {:noreply, assign(socket, :settlement_time, time)}
  end

  def handle_event("submit", %{"transaction_type" => "buy"} = params, socket) do
    with current_user <- get_current_user(socket.assigns.current_user_session),
         asset <- get_asset(params),
         market <- get_market(params, asset),
         {:ok, _trx} <- insert_buy_transaction(current_user, asset, market, params) do
      {:noreply,
       put_flash(socket, :info, gettext("Transaction has been filled"))
       |> redirect(to: "/transactions")}
    end
  end

  def handle_event(type, _, socket) do
    IO.inspect({"type", type})
    {:noreply, socket}
  end

  defp get_asset(%{"asset_id" => asset_id}), do: get_asset(asset_id)
  defp get_asset(asset_id), do: Munchkin.Inventory.get_asset(asset_id)

  defp get_market(%{"market_id" => market_id}, asset), do: get_market(market_id, asset)

  defp get_market("", asset) do
    asset.tickers
    |> Enum.at(0)
    |> Munchkin.Repo.preload([:market])
    |> Map.get(:market)
    |> case do
      nil -> get_market(1000, asset)
      market -> market
    end
  end

  defp get_market(market_id, asset) do
    case Munchkin.Inventory.get_market(market_id) do
      %Munchkin.Inventory.Market{} = m -> m
      _ -> asset.tickers |> Enum.at(0) |> Munchkin.Repo.preload([:market]) |> Map.get(:market)
    end
  end

  defp insert_buy_transaction(user, asset, market, params) do
    Map.take(params, [
      "price",
      "reference_id",
      "quantity",
      "settlement_date",
      "transaction_date",
      "asset_id"
    ])
    |> Map.put("market", market)
    |> Map.put("asset", asset)
    |> Map.put("user", user)
    |> Map.put("transaction_type", Munchkin.Inventory.TransactionType.buy())
    |> Map.put("user_id", user.id)
    |> Munchkin.Inventory.add_transactions()
  end

  defp assign_market(socket) do
    assign_new(socket, :available_market, fn _ ->
      Munchkin.Inventory.get_available_market()
      |> then(fn
        {:ok, [_ | _] = markets} ->
          Enum.map(markets, fn m ->
            case Map.get(m.details, "legal_name") do
              name when is_bitstring(name) -> "#{m.name} (#{name})"
              _ -> m.name
            end
            |> then(fn l ->
              {l, m.id}
            end)
          end)

        _ ->
          []
      end)
    end)
  end

  def render(assigns) do
    ~H"""
    <div class="w-full">
      <.form
        class="w-full"
        phx-change="handle_change"
        phx-target={@myself}
        for={@form}
        phx-submit="submit"
        id="transaction_form"
      >
        <input type="hidden" name="transaction_type" value="buy" />
        <div class="mt-4 w-full">
          <div>
            <fieldset class="fieldset">
              <legend class="fieldset-legend">
                <.label text={gettext("Company Name")} required id="buy-select-ticker-label" />
                <.infotip value={gettext("A company you want to buy")} />
              </legend>
              <select
                phx-hook="ChoicesHook"
                id="buy-select-ticker"
                name="asset_id"
                required
                data-url="/transactions/search-ticker"
                data-ref="transaction_type"
                data-no-result="Cannot find given name"
                data-no-choice={gettext("Cannot find company with given specification")}
                data-not-found="Company with those specification is not exists"
                data-placeholder="Search a company"
              ></select>
            </fieldset>
            <.input
              type="select"
              info={
                gettext(
                  "Platform to do the transaction, should be securities. This can determine the tax, fees, etc"
                )
              }
              label={gettext("Market")}
              prompt={gettext("Select the market")}
              options={@available_market}
              name="market_id"
              id="buy_market_id"
              value={0}
            />
            <div class="grid grid-cols-2 gap-4">
              <.input
                label={gettext("Transaction Time")}
                info={gettext("Transaction time. Can be exact or just end of day trade")}
                required
                type="datetime-local"
                name="transaction_date"
                id="buy_transaction_date"
                field={@form[:transaction_date]}
              />
              <div>
                <.input
                  label={gettext("Settlement Time")}
                  info={
                    gettext("Settlement of transaction time. Can be exact or just end of day trade")
                  }
                  type="datetime-local"
                  phx-hook="TogglerHook"
                  id="buy_settlement_date"
                  data-target="#reference_no_container"
                  field={@form[:settlement_date]}
                />
                <div id="reference_no_container" class="hidden w-full">
                  <.input
                    info={gettext("Can be blank but better to fill this to maintain the audit")}
                    label={gettext("Reference Number")}
                    field={@form[:reference_id]}
                  />
                </div>
              </div>
            </div>

            <div class="grid grid-cols-2 gap-4">
              <.input
                label={gettext("Price")}
                type="number"
                required
                id="buy_price"
                info={gettext("The exact price you've traded in")}
                placeholder={gettext("Enter you traded price")}
                field={@form[:price]}
              />
              <.input
                label={gettext("Shares")}
                required
                type="number"
                id="buy_quantity"
                info={gettext("The exact shares you've traded in ")}
                placeholder={gettext("Enter you desired shares")}
                field={@form[:quantity]}
              />
            </div>
          </div>

          <div class="flex w-full justify-end">
            <div class="w-1/5 grid grid-cols-2 gap-2">
              <.button variant="primary">{gettext("Submit")}</.button>
              <.button
                type="button"
                variant="plain"
                phx-click={JS.dispatch("click", to: "#transaction_modal-close")}
              >
                {gettext("Back")}
              </.button>
            </div>
          </div>
        </div>
      </.form>
    </div>
    """
  end
end
