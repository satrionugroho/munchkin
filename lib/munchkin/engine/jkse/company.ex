defmodule Munchkin.Engine.Jkse.Company do
  use Munchkin.Engine.Jkse.Engine

  alias Munchkin.Engine.Jkse.SimpleCache

  def profile(ticker) when is_bitstring(ticker) do
    path = get_url(:company_profile, %{"KodeEmiten" => ticker})

    fetch(path, timeout: :timer.seconds(45))
    |> parse_data()
  end

  def announcement(ticker) when is_bitstring(ticker) do
    path = get_url(:company_announcement, %{"KodeEmiten" => ticker})
    fetch(path, timeout: :timer.seconds(45))
  end

  def esg do
    path = get_url(:company_esg)

    fetch(path, [])
    |> case do
      {:ok, %{"result" => result}} -> {:ok, parse_esg(result)}
      err -> err
    end
  end

  def corporate_action(ticker \\ nil) do
    path = get_url(:corporate_action)

    SimpleCache.get_or_update(:corporate_action, fn ->
      fetch(path, [])
    end)
    |> case do
      {:ok, %{"data" => data}} -> parse_corporate_action_data(data, ticker)
      _ -> {:error, "cannot get corporate action"}
    end
  end

  defp parse_data({:ok, %{"Profiles" => data}}) do
    List.first(data, %{})
    |> Enum.reduce({%{}, %{}}, fn {k, value}, {result, metadata} ->
      key = translate(k)

      case important?(key) do
        true -> {Map.put(result, key, translate_value(key, value)), metadata}
        _ -> {result, Map.put(metadata, key, translate_value(key, value))}
      end
    end)
    |> then(fn {data, meta} ->
      Map.put(data, "metadata", Map.drop(meta, ["drop", "ticker"]))
    end)
  end

  defp parse_data(err), do: err

  defp important?(key) do
    Enum.member?(
      [
        "name",
        "address",
        "email",
        "issued_date",
        "website",
        "sector",
        "subsector",
        "industry",
        "subindustry"
      ],
      key
    )
  end

  defp parse_corporate_action_data(data, ticker) when ticker in [nil, ""] do
    Enum.map(data, &translate_corporate_action/1)
    |> Enum.sort_by(& &1["date"], {:desc, Date})
    |> then(fn d -> {:ok, d} end)
  end

  defp parse_corporate_action_data(data, ticker) do
    Enum.filter(data, fn %{"KodeEmiten" => t} ->
      String.downcase(t)
      |> String.equivalent?(String.downcase(ticker))
    end)
    |> Enum.map(&translate_corporate_action/1)
    |> Enum.sort_by(& &1["date"], {:desc, Date})
    |> then(fn d -> {:ok, d} end)
  end

  defp translate_corporate_action(data) do
    Enum.reduce(data, %{}, fn
      {k, value}, acc when k == "TanggalPencatatan" ->
        key = Map.get(corporate_action_translation(), k)
        val = Munchkin.Engine.Jkse.Utils.string_to_date(value)
        Map.put(acc, key, val)

      {k, value}, acc when k == "JenisTindakan" ->
        key = Map.get(corporate_action_translation(), k)
        val = Map.get(corporate_action_list(), value)

        Map.put(acc, key, val)

      {k, value}, acc ->
        key = Map.get(corporate_action_translation(), k)
        Map.put(acc, key, value)
    end)
  end

  defp translate(key) do
    Map.get(dict(), key, "drop")
  end

  defp translate_value(key, val) when key in ["issued_date", "last_update"] do
    DateTime.from_iso8601(val <> "Z")
    |> case do
      {:ok, dt, _} -> DateTime.to_date(dt) |> Date.to_string()
      _ -> val
    end
  end

  defp translate_value(_key, val) when is_bitstring(val) do
    String.trim(val)
  end

  defp translate_value(_key, val), do: val

  defp parse_esg(data) do
    Enum.map(data, fn d ->
      Enum.reduce(d, %{}, fn {key, value}, acc ->
        k = translate(key)
        Map.put(acc, k, translate_value(k, value))
      end)
    end)
  end

  defp dict do
    %{
      "Alamat" => "address",
      "BAE" => "bae",
      "Divisi" => "division",
      "EfekEmiten_EBA" => "eba_issuer",
      "EfekEmiten_ETF" => "etf_issuer",
      "EfekEmiten_Obligasi" => "bond_issuer",
      "EfekEmiten_SPEI" => "spei_issuer",
      "EfekEmiten_Saham" => "stock_issuer",
      "Email" => "email",
      "Fax" => "fax",
      "Industri" => "industry",
      "KegiatanUsahaUtama" => "business_activity",
      "KodeDivisi" => "division_code",
      "KodeEmiten" => "ticker",
      "Logo" => "logo",
      "NPKP" => "npkp",
      "NPWP" => "npwp",
      "NamaEmiten" => "name",
      "PapanPencatatan" => "board",
      "Sektor" => "sector",
      "Status" => "status",
      "SubIndustri" => "subindustry",
      "SubSektor" => "subsector",
      "TanggalPencatatan" => "issued_date",
      "Telepon" => "phone",
      "Website" => "website",
      "ESGRiskLevel" => "risk_level",
      "ESGScore" => "score",
      "ESGStatus" => "status",
      "EntityName" => "name",
      "LastUpdate" => "last_update",
      "TickerCode" => "ticker"
    }
  end

  defp corporate_action_translation() do
    %{
      "JenisTindakan" => "action",
      "JumlahSaham" => "quantity",
      "JumlahSahamSetelahTindakan" => "become_quantity",
      "KodeEmiten" => "ticker",
      "TanggalPencatatan" => "date",
      "id" => "id"
    }
  end

  defp corporate_action_list() do
    Munchkin.Engine.Jkse.Utils.corporate_actions_translation()
    |> Enum.map(fn %{label: label, key: key} -> {key, label} end)
    |> Enum.into(%{})
  end
end
