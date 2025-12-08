defmodule MunchkinWeb.API.V1.CompanyJSON do
  def render("show.json", %{company: company}) do
    %{
      data: company_data(company),
      messages: [],
      actions: "get company"
    }
  end

  def render("eod.json", %{trades: trades}) do
    %{
      data: Enum.map(trades, &trade_history/1),
      messages: [],
      actions: "get trade history"
    }
  end

  def render("last_trade.json", %{trade: trade}) do
    %{
      data: trade_history(trade),
      messages: [],
      actions: "get last trade history"
    }
  end

  def render("error.json", %{messages: messages, actions: actions}) do
    %{
      data: nil,
      messages: messages,
      actions: actions
    }
  end

  defp company_data(asset) do
    Map.take(asset, [
      :id,
      :name,
      :address,
      :email,
      :website,
      :sector,
      :subsector,
      :industry,
      :subindustry
    ])
  end

  defp trade_history(trade) do
    Map.from_struct(trade)
    |> Enum.reduce(%{}, fn
      {key, val}, acc when key in [:open, :high, :low, :close] ->
        Map.put(acc, key, Decimal.to_float(val))

      {:shares, val}, acc ->
        Map.put(acc, :shares, Decimal.to_integer(val))

      {:date, val}, acc ->
        Map.put(acc, :date, val)

      _, acc ->
        acc
    end)
  end
end
