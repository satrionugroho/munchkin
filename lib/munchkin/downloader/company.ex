defmodule Munchkin.Downloader.Company do
  def download_profile do
    Munchkin.Engine.Jkse.Stock.list()
    |> case do
      {:ok, data} -> Enum.map(data, &Map.take(&1, ["ticker"]))
      _ -> []
    end
    |> download_profile()
  end

  defp download_profile(data) do
    Enum.map(data, fn d ->
      Munchkin.Downloader.download({__MODULE__, :individual_company_profile, [d]})
    end)
  end

  def individual_company_profile(ticker) do
    case Munchkin.Inventory.get_asset(ticker) do
      %Munchkin.Inventory.Asset{} = asset ->
        {:ok, asset}

      _ ->
        Munchkin.Engine.Jkse.Company.profile(ticker)
        |> Map.put("ticker", ticker)
        |> Map.put("type_id", "stock")
        |> Map.put("exchange", "JK")
        |> Map.put("source", Munchkin.Engine.Jkse.Instance.get())
        |> Munchkin.Inventory.create_asset()
    end
  end

  def individual_fundamental_data(ticker, given_year \\ nil) do
    year = given_year || Date.utc_today().year

    Munchkin.Engine.Jkse.Fundamental.Type.periods()
    |> Enum.map(fn p ->
      period = Kernel.<>(to_string(year), p)
      Munchkin.Engine.Jkse.Fundamental.get(ticker, period: period)
    end)
  end
end
