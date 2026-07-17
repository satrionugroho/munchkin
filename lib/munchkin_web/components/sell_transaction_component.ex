defmodule MunchkinWeb.SellTransactionComponent do
  use MunchkinWeb, :live_component

  alias Munchkin.Inventory.Transaction

  def mount(socket) do
    connected?(socket)
    |> then(fn
      true ->
        assign(socket,
          settlement_time: nil,
          available_assets: [],
          quantity: 0,
          price: 0,
          errors: %{},
          current_user_session: "",
          portfolio: []
        )
        |> assign_market()

      _ ->
        assign(socket,
          settlement_time: nil,
          available_assets: [],
          quantity: 0,
          price: 0,
          errors: %{},
          available_market: [],
          portfolio: []
        )
    end)
    |> ok()
  end

  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:form, fn ->
      Munchkin.Inventory.change_transaction(%Transaction{})
      |> to_form()
    end)
    |> assign_portfolio()
    |> ok()
  end

  def handle_event(
        "handle_change",
        %{"transaction" => trx, "asset_id" => id},
        socket
      ) do
    with {:ok, portfolio} <- get_current_portfolio(socket, id),
         changeset <- parse_changeset(trx, id, portfolio, :cast),
         errors <- parse_errors(changeset),
         form <- to_form(changeset) do
      assign(socket, form: form, errors: errors)
    else
      {:error, err} -> assign(socket, :error, err)
    end
    |> noreply()
  end

  def handle_event("submit", %{"transaction" => params, "asset_id" => id} = whole_params, socket) do
    with user <- get_current_user(socket),
         asset <- get_asset(id),
         market <- get_market(whole_params, asset),
         {:ok, portfolio} <- get_current_portfolio(socket, id),
         trx_params <-
           Map.merge(params, %{
             "transaction_type" => "sell",
             "sell_method" => Map.get(whole_params, "sell_method", "lifo"),
             "market" => market,
             "asset" => asset,
             "asset_id" => asset.id,
             "user_id" => user.id
           }),
         {:ok, trx} <- parse_changeset(trx_params, id, portfolio, :insert) do
      IO.inspect(trx)
      {:noreply, socket}
    end
  end

  def handle_event(_, _, socket) do
    noreply(socket)
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

  defp parse_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts
        |> Keyword.get(String.to_existing_atom(key), key)
        |> to_string()
      end)
    end)
  end

  defp get_current_portfolio(socket, id) do
    asset_id = String.to_integer(id)

    Map.get(socket.assigns, :portfolio)
    |> Enum.find(fn {k, _} -> k == asset_id end)
    |> case do
      {_, value} -> {:ok, value}
      _ -> {:error, "portfolio not found"}
    end
  end

  defp parse_changeset(params, id, portfolio, :cast) do
    Map.put(params, "asset_id", id)
    |> then(&Munchkin.Inventory.change_transaction(%Transaction{}, &1))
    |> Ecto.Changeset.apply_action(:insert)
    |> case do
      {_, %Ecto.Changeset{} = changeset} -> Transaction.validate(changeset, portfolio)
      _ -> nil
    end
  end

  defp parse_changeset(params, id, portfolio, _) do
    params
    |> Map.put("asset_id", id)
    |> Map.put("portfolio", portfolio)
    |> Munchkin.Inventory.add_transactions()
  end

  defp assign_portfolio(socket) do
    connected?(socket)
    |> then(fn
      true ->
        get_current_user(socket)
        |> case do
          user when is_map(user) -> do_get_available_assets(user, socket)
          _ -> assign(socket, available_assets: [], asset_options: [], portfolio: [])
        end

      _ ->
        assign(socket, available_assets: [], asset_options: [], portfolio: [])
    end)
  end

  defp do_get_available_assets(user, socket) do
    user
    |> Munchkin.Inventory.user_portfolio()
    |> then(fn
      {:ok, porto} ->
        available_assets =
          Map.keys(porto)
          |> Munchkin.Inventory.get_multiple_assets()

        options = parse_asset_to_options(available_assets)

        assign(socket,
          available_assets: available_assets,
          asset_options: options,
          portfolio: porto
        )

      _ ->
        assign(socket, available_assets: [], asset_options: [], portfolio: [])
    end)
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

  defp parse_asset_to_options(assets) do
    Enum.map(assets, fn a ->
      ticker = a.tickers |> parse_ticker()
      %{id: a.id, label: "#{a.name} (#{ticker})"}
    end)
  end

  defp parse_ticker(tickers) when length(tickers) > 0 do
    t = List.first(tickers)
    "#{t.ticker}-#{t.exchange}"
  end

  defp parse_ticker(_), do: "DUMP-JK"

  def render(assigns) do
    ~H"""
    <div class="w-full">
      <.form
        class="w-full"
        phx-change="handle_change"
        phx-target={@myself}
        phx-submit="submit"
        for={@form}
        id="transaction_sell_form"
      >
        <input name="transaction_type" type="hidden" value="sell" />
        <div class="mt-4 w-full">
          <div>
            <fieldset class="fieldset">
              <legend class="fieldset-legend">
                <.label text={gettext("Company Name")} required id="select-ticker" />
                <.infotip value={gettext("A company you want to sell")} />
              </legend>
              <select
                phx-hook="ChoicesHook"
                id="select-ticker"
                name="asset_id"
                required
                data-ref="transaction_type"
                data-no-result="Cannot find given name"
                data-no-choice={gettext("Cannot find company with given specification")}
                data-not-found="Company with those specification is not exists"
                data-placeholder="Search a company"
              >
                <option :for={opt <- @asset_options} value={Map.get(opt, :id)}>
                  {Map.get(opt, :label)}
                </option>
              </select>
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
              value={0}
            />
            <div class="grid grid-cols-2 gap-4">
              <fieldset class="fieldset">
                <legend class="fieldset-legend">
                  <.label text={gettext("Selling Method")} required id="sell_method" />
                  <.infotip value={gettext("Sell methodology")} />
                </legend>
                <select
                  phx-hook="ChoicesHook"
                  id="sell_method"
                  name="sell_method"
                  required
                  data-placeholder="Sell Method"
                >
                  <option value="fifo">{gettext("FIFO (First In First Out)")}</option>
                  <option value="lifo">{gettext("LIFO (Last In First Out)")}</option>
                  <option disabled value="3">{gettext("Select a transaction")}</option>
                </select>
              </fieldset>
            </div>
            <div class="grid grid-cols-2 gap-4">
              <.input
                label={gettext("Transaction Time")}
                info={gettext("Transaction time. Can be exact or just end of day trade")}
                required
                type="datetime-local"
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
                field={@form[:price]}
                placeholder={gettext("Input your selling price. Ex: 2000")}
                info={gettext("The exact price you've traded out")}
              />
              <.input
                label={gettext("Shares")}
                required
                type="number"
                placeholder={gettext("Input your selling share(s). Ex: 200")}
                info={gettext("The exact shares you've traded out")}
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
