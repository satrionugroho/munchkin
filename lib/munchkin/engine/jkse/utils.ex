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
