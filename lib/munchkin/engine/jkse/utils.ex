defmodule Munchkin.Engine.Jkse.Utils do
  def parse_date(datestring) when is_bitstring(datestring) do
    {day, [monthname, year]} =
      String.split(datestring, " ")
      |> List.pop_at(0)

    Date.new(parse_year(year), parse_month(monthname), parse_day(day))
  end

  def parse_date(date), do: date

  def string_to_date(date_string) do
    date_string
    |> Kernel.<>("Z")
    |> DateTime.from_iso8601()
    |> case do
      {:ok, date, _} -> DateTime.to_date(date)
      _err -> nil
    end
  end

  def corporate_actions_translation() do
    [
      %{key: "delist", id: -1, label: "Delisting"},
      %{key: "waran", id: 1, label: "Warant"},
      %{key: "stockSplit", id: 2, label: "Stock Split"},
      %{key: "hmetd", id: 3, label: "Right Issue"},
      %{key: "ipo", id: 4, label: "Initial Public Offerring"},
      %{key: "tanpaHmetd", id: 5, label: "Private Placement"},
      %{key: "Dividen Saham", id: 6, label: "Dividend"},
      %{key: "sahamBonus", id: 7, label: "Stock Bonus"},
      %{key: "gabungUsaha", id: 8, label: "Joint Venture"},
      %{key: "kurangModal", id: 9, label: ""},
      %{key: "partialDelisting", id: 10, label: "Partial Delisting"},
      %{key: "obligasiWajibKonversi", id: 11, label: "Mandatory Convertible Bond"},
      %{key: "partialRelisting", id: 12, label: "Partial Relisting"},
      %{key: "esopMsop", id: 13, label: "ESOP/MSOP"},
      %{key: "KonversiSaham", id: 14, label: "Stock Conversion"},
      %{key: "CompanyListing", id: 15, label: "Company Listing"},
      %{key: "BuybackSaham", id: 16, label: "Buyback Stock"},
      %{key: "MSOP", id: 17, label: "MSOP"},
      %{key: "PrivatePlacement", id: 18, label: "Private Placement (+)"},
      %{key: "ESOP", id: 19, label: "ESOP"},
      %{key: "reverseStock", id: 20, label: "Reverse Stock"},
      %{key: "TransaksiMaterial", id: 21, label: "Material Transaction"}
    ]
  end

  defp parse_year(num), do: safe_parse_integer(num, Date.utc_today().year)
  defp parse_day(num), do: safe_parse_integer(num, Date.utc_today().day)

  defp parse_month(month) when is_bitstring(month) do
    case Map.get(dict(), month) do
      nil -> safe_parse_integer(month, Date.utc_today().month)
      data -> data
    end
  end

  defp parse_month(month), do: month

  defp dict do
    %{
      "january" => 1,
      "januari" => 1,
      "february" => 2,
      "februari" => 2,
      "march" => 3,
      "maret" => 3,
      "april" => 4,
      "may" => 5,
      "mei" => 5,
      "june" => 6,
      "juni" => 6,
      "july" => 7,
      "juli" => 7,
      "august" => 8,
      "agustus" => 8,
      "september" => 9,
      "october" => 10,
      "oktober" => 10,
      "november" => 11,
      "december" => 12,
      "desember" => 12
    }
  end

  def safe_parse_integer(num, default) when is_bitstring(num) do
    try do
      String.to_integer(num)
    rescue
      _ -> default
    end
  end

  def safe_parse_integer(num, _default), do: num
end
