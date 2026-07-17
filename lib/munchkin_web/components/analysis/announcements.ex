defmodule MunchkinWeb.Analysis.Announcements do
  use MunchkinWeb, :live_component

  def update(assigns, socket) do
    assign(socket, assigns)
    |> then(fn s ->
      [ticker, _exchange] = s.assigns.ticker |> String.split(".", parts: 2)

      assign_async(s, [:corporate_actions, :profile], fn ->
        get_corporate_action(ticker)
      end)
    end)
    |> ok()
  end

  defp get_corporate_action(ticker) do
    asset = Munchkin.Inventory.get_asset(ticker)

    Munchkin.Engine.Jkse.Company.corporate_action(ticker)
    |> case do
      {:ok, data} -> {:ok, %{corporate_actions: data, profile: asset}}
      _ -> {:error, %{corporate_actions: "cannot get corporate action", profile: asset}}
    end
  end

  defp number_value(assigns) do
    ~H"""
    <span>{Munchkin.Cldr.Number.to_string!(@number)}</span>
    """
  end

  def render(assigns) do
    ~H"""
    <div>
      <div class="grid grid-cols-2 gap-4">
        <div>
          <h2 class="font-bold text-xl mb-3">{gettext("Profile")}</h2>
          <.async_result :let={profile} assign={@profile}>
            <.list>
              <:item title={gettext("Name")}>{profile.name}</:item>
              <:item title={gettext("Office Address")}>{profile.address}</:item>
              <:item title={gettext("Email Address")}>{profile.email}</:item>
              <:item title={gettext("Phone & Fax")}>
                <span>{profile.metadata["phone"]}</span>
                <span class="ml-2">& {profile.metadata["fax"]}</span>
              </:item>
              <:item title={gettext("NPWP")}>{profile.metadata["npwp"]}</:item>
              <:item title={gettext("Website")}>{profile.website}</:item>
              <:item title={gettext("Listing Information")}>
                <div class="flex flex-col">
                  <div>
                    <span class="font-bold">{gettext("Board")}:</span>
                    <span>{profile.metadata["board"]}</span>
                  </div>
                  <div>
                    <span class="font-bold">{gettext("Date")}:</span>
                    <span>{profile.issued_date}</span>
                  </div>
                </div>
              </:item>
              <:item title={gettext("Sector - Subsector")}>
                <span class="mr-1">{titleize(profile.sector)}</span>
                <span>-</span>
                <span class="ml-1">{titleize(profile.subsector)}</span>
              </:item>
              <:item title={gettext("Industry - Subindustry")}>
                <span class="mr-1">{titleize(profile.industry)}</span>
                <span>-</span>
                <span class="ml-1">({titleize(profile.subindustry)})</span>
              </:item>
              <:item title={gettext("Register")}>{Map.get(profile.metadata, "bae", "-")}</:item>
            </.list>
          </.async_result>
        </div>
        <div>
          <h2 class="font-bold text-xl mb-3">{gettext("Corporate Actions")}</h2>
          <.async_result :let={cas} assign={@corporate_actions}>
            <.list>
              <:item :for={c <- cas} header_class="text-lg" title={c["action"]}>
                <div class="w-full flex flex-col mt-2">
                  <div class="w-full flex items-center">
                    <div class="w-[120px] text-bold">{gettext("Date Issued")}</div>
                    <div class="w-2/3">{c["date"]}</div>
                  </div>
                  <div class="w-full flex items-center mt-2">
                    <div class="w-[120px] text-bold">{gettext("Current Value")}</div>
                    <div class="w-2/3">
                      <.number_value number={c["quantity"]}/>
                    </div>
                  </div>
                  <div class="w-full flex items-center mt-2">
                    <div class="w-[120px] text-bold">{gettext("Planned Value")}</div>
                    <div class="w-2/3">
                      <.number_value number={c["become_quantity"]}/>
                    </div>
                  </div>
                </div>
              </:item>
            </.list>
          </.async_result>
        </div>
      </div>
    </div>
    """
  end
end
