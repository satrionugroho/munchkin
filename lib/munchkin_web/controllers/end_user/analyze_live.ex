defmodule MunchkinWeb.EndUser.AnalyzeLive do
  use MunchkinWeb, :live_view

  def mount(_params, session, socket) do
    assign_user_id(session, socket)
    |> ok()
  end

  def handle_params(params, _, socket) do
    socket
    |> apply_action(params)
    |> noreply()
  end

  def handle_event("search", %{"ticker" => ticker}, socket) do
    push_patch(socket, to: "/analyze/#{ticker}", replace: true)
    |> noreply()
  end

  defp apply_action(socket, %{"ticker" => ticker}) do
    connected?(socket)
    |> then(fn
      true ->
        find_correlated_asset(socket, ticker)

      _ ->
        assign(socket, live_action: nil, ticker: "")
    end)
  end

  defp apply_action(socket, _) do
    form =
      %Munchkin.Inventory.Asset{}
      |> Munchkin.Inventory.Asset.changeset(%{})
      |> Phoenix.Component.to_form()

    socket
    |> assign(:form, form)
    |> assign(:live_action, :index)
  end

  defp find_correlated_asset(socket, ticker) do
    case Munchkin.Inventory.get_asset(ticker) do
      %Munchkin.Inventory.Asset{} = a ->
        socket
        |> assign_new(:ticker, fn -> ticker end)
        |> assign(asset: a, live_action: :show)
        |> assign(
          data: [
            %{id: 1, name: "Elixir", website: "https://elixir-lang.org"},
            %{id: 2, name: "Erlang", website: "https://www.erlang.org"}
          ]
        )

      _ ->
        socket
        |> assign_new(:ticker, fn -> ticker end)
        |> apply_action(nil)
        |> assign(live_action: :error)
    end
  end
end
