defmodule MunchkinWeb.EndUser.TransactionLive do
  alias Phoenix.LiveView.AsyncResult
  use MunchkinWeb, :live_view

  def mount(_, session, socket) do
    assign_user_id(session, socket)
    |> assign(
      current_page: 1,
      each_page: 20,
      tab: "executed",
      total: 100,
      total_detailed: %{},
      total_transaction: 0,
      current_month_transaction: 0,
      paginated?: false,
      modal: ""
    )
    |> get_transactions_async()
    |> ok()
  end

  def handle_params(_params, _uri, socket) do
    connected?(socket)
    |> then(fn
      true ->
        socket
        |> get_stats()
        |> assign(current_page: 1, each_page: 20, tab: "executed", total: 100, paginated?: false)

      _ ->
        socket
    end)
    |> noreply()
  end

  def handle_event(
        "verify",
        %{"transaction_id" => id, "reference_id" => ref},
        %{assigns: assigns} = socket
      ) do
    Map.get(assigns, :transactions)
    |> Enum.find(&Kernel.==(&1.id, id))
    |> case do
      %Munchkin.Inventory.Transaction{} = trx ->
        do_update_transaction(socket, trx, ref)

      _ ->
        {:noreply,
         put_flash(socket, :error, gettext("Cannot find the transaction"))
         |> redirect(to: "/transactions")}
    end
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    assign(socket, :current_page, String.to_integer(page))
    |> get_transactions_async()
    |> noreply()
  end

  def handle_event("change-tab", %{"tab" => tab}, socket) do
    active_tab = String.downcase(tab)

    assign(socket, :tab, active_tab)
    |> get_transactions_async()
    |> noreply()
  end

  def handle_event("open-modal", %{"id" => modal_id}, socket) do
    assign(socket, :modal, modal_id)
    |> noreply()
  end

  def handle_event("close-modal", _, socket) do
    assign(socket, :modal, "")
    |> noreply()
  end

  defp do_update_transaction(socket, trx, ref) do
    trx
    |> Munchkin.Inventory.set_transaction_settlement(%{"reference_id" => ref})
    |> case do
      {:ok, _trx} -> put_flash(socket, :info, gettext("Transaction was updated sucessfully"))
      _ -> put_flash(socket, :error, gettext("An error occurred when updating the transactions"))
    end
    |> redirect(to: "/transactions", force: true)
    |> then(fn s -> {:noreply, s} end)
  end

  defp get_transactions_async(socket) do
    current_user = get_current_user(socket)
    type = socket.assigns.tab
    limit = socket.assigns.each_page
    page = socket.assigns.current_page
    tab = socket.assigns.tab
    total_detailed = socket.assigns.total_detailed

    assign_async(
      socket,
      :transactions,
      fn ->
        get_user_transaction(current_user,
          type: type,
          limit: limit,
          page: page,
          tab: tab,
          total_detailed: total_detailed
        )
      end
    )
  end

  defp get_user_transaction(user, opts) do
    page = Keyword.get(opts, :page)
    limit = Keyword.get(opts, :limit)

    Munchkin.Inventory.get_user_transactions(user,
      status: Keyword.get(opts, :type),
      limit: limit,
      offset: (page - 1) * limit
    )
    |> then(fn trx -> {:ok, %{transactions: trx}} end)
  end

  defp get_stats(socket) do
    get_total_user_transactions(socket)
    |> get_current_month_transaction()
  end

  defp get_total_user_transactions(socket) do
    get_current_user(socket)
    |> Munchkin.Inventory.get_total_user_transactions()
    |> then(fn
      {:ok, total} when is_map(total) ->
        tab = socket.assigns.tab
        trx = Enum.reduce(total, 0, fn {_, val}, acc -> val + acc end)
        max_page = socket.assigns.each_page
        current_total = Map.get(total, tab, 0)

        assign(socket, :total_detailed, total)
        |> assign(:total_transaction, trx)
        |> assign(:paginated?, current_total > max_page)

      _ ->
        assign(socket, total_transaction: 0, total_detailed: %{})
    end)
  end

  defp get_current_month_transaction(socket) do
    get_current_user(socket)
    |> Munchkin.Inventory.get_current_month_amount_user_transactions()
    |> then(fn
      {:ok, total} -> assign(socket, :current_month_transaction, total)
      _ -> assign(socket, :current_month_transaction, 0)
    end)
  end

  def json_data(trx) do
    Map.from_struct(trx)
    |> Map.take([
      :id,
      :status,
      :inserted_at,
      :transaction_type,
      :price,
      :quantity,
      :fee,
      :total_value,
      :reference_id,
      :settlement_date
    ])
    |> Map.put(:asset_name, trx.asset.name)
    |> Map.put(:asset_id, trx.asset.id)
    |> JSON.encode_to_iodata!()
  end
end
