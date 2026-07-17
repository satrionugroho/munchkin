defmodule MunchkinWeb.AnalysisTemplate do
  use MunchkinWeb, :live_component

  def mount(socket) do
    socket
    |> default_data()
    |> ok()
  end

  def update(assigns, socket) do
    assign(socket, assigns)
    |> assign_new(:period_gap, fn -> 3 end)
    |> assign_new(:current_year, fn -> Date.utc_today().year end)
    |> then(fn s ->
      ticker = s.assigns.ticker
      ey = s.assigns.current_year
      gap = s.assigns.period_gap

      assign_async(s, :data_ref, fn -> get_fundamental_raw_data(ticker, ey, gap) end)
    end)
    |> ok()
  end

  def handle_event("change-tab", %{"id" => name, "value" => "on"}, socket) do
    socket
    |> assign(:active, name)
    |> noreply()
  end

  def default_data(socket) do
    assign(socket, active: "fundamentals")
    |> assign(:modes, available_modes())
  end

  defp get_fundamental_raw_data(ticker, start_year, end_year) do
    Munchkin.Cache.random_eval(
      fn ->
        Range.new(start_year, end_year)
        |> Enum.into([])
        |> then(&Munchkin.Inventory.get_fundamental_data(ticker, &1))
      end,
      :timer.minutes(5)
    )
    |> case do
      {:ok, key} -> {:ok, %{data_ref: key}}
      _ -> {:error, %{data_ref: nil}}
    end
  end

  defp available_modes do
    [
      %{
        id: 1,
        name: "fundamentals",
        label: gettext("Fundamentals"),
        module: MunchkinWeb.Analysis.Keystat
      },
      %{
        id: 2,
        name: "corporate_action",
        label: gettext("Announcements"),
        module: MunchkinWeb.Analysis.Announcements
      }
    ]
    |> Enum.sort_by(&Map.get(&1, :id))
  end

  def evaluate_data(socket) do
    []
  end

  def render(assigns) do
    ~H"""
    <div>
      <.async_result :let={ref} assign={@data_ref}>
        <div class="tabs tabs-box">
          <.tab_item
            :for={m <- @modes}
            name={m.name}
            label={m.label}
            checked={@active == m.name}
            myself={@myself}
          >
            <.live_component
              module={m.module}
              ticker={@ticker}
              data_ref={ref}
              session={@session}
              id={"id_for_#{m.name}"}
            />
          </.tab_item>
        </div>
      </.async_result>
    </div>
    """
  end

  defp tab_item(assigns) do
    ~H"""
    <input
      type="radio"
      name={@name}
      class="tab"
      aria-label={@label}
      checked={@checked}
      phx-click="change-tab"
      phx-value-id={@name}
      phx-target={@myself}
    />
    <div class="tab-content bg-base-100 border-base-300 p-3">
      {render_slot(@inner_block)}
    </div>
    """
  end
end
