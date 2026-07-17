defmodule MunchkinWeb.StringFormatterHelper do
  def titleize(string) when is_bitstring(string) do
    string
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  def concatenate(string, opts \\ []) do
    start = Keyword.get(opts, :start, 0)
    final = Keyword.get(opts, :end, 8)

    String.slice(string, start, final)
    |> Kernel.<>("...")
  end

  def intl_date(date, opts \\ [])

  def intl_date(%Date{} = date, _opts) do
    Munchkin.Cldr.Date.to_string(date)
    |> case do
      {:ok, d} -> d
      _ -> "error"
    end
  end

  def intl_date(%DateTime{} = date, opts) do
    case Keyword.get(opts, :format, :default) do
      :default -> Munchkin.Cldr.DateTime.to_string(date, format: :yMMMd)
      f -> Munchkin.Cldr.DateTime.to_string(date, format: f)
    end
    |> case do
      {:ok, d} -> d
      _ -> "error"
    end
  end

  def intl_date(string, opts) when is_bitstring(string) do
    DateTime.from_iso8601(string)
    |> case do
      {:ok, dt} -> intl_date(dt, opts)
      _ -> "error"
    end
  end

  def currency_format(number, opts \\ [])

  def currency_format(string, opts) when is_bitstring(string) do
    try do
      s = String.to_integer(string)
      currency_format(s, opts)
    rescue
      ArgumentError ->
        s = String.to_float(string)
        currency_format(s, opts)
    end
  end

  def currency_format(int, opts) when is_number(int) do
    type = Keyword.get(opts, :type, :short)

    int
    |> Munchkin.Cldr.Number.to_string(currency: :idr, format: type, currency_symbol: :narrow)
    |> case do
      {:ok, s} -> s
      _ -> "..."
    end
  end

  def currency_format(%Decimal{} = decimal, opts) do
    decimal
    |> Decimal.to_float()
    |> currency_format(opts)
  end

  def number_format(any, opts \\ [])

  def number_format(string, opts) when is_bitstring(string) do
    try do
      s = String.to_integer(string)
      number_format(s, opts)
    rescue
      ArgumentError ->
        s = String.to_float(string)
        number_format(s, opts)
    end
  end

  def number_format(number, opts) when is_number(number) do
    type = Keyword.get(opts, :type, :short)

    number
    |> Munchkin.Cldr.Number.to_string(format: type)
    |> case do
      {:ok, s} -> s
      _ -> "..."
    end
  end

  def number_format(%Decimal{} = d, opts) do
    d
    |> Decimal.to_float()
    |> number_format(opts)
  end
end
