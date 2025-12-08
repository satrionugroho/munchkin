defmodule Munchkin.Inventory.Fundamental.Schema do
  alias Munchkin.Inventory.Fundamental.Provider.Factset
  alias Munchkin.Inventory.Fundamental.Provider.IDX, as: FundamentalIDX
  alias Munchkin.Inventory.Fundamental.{BalanceSheet, Cashflow, General, IncomeStatement}

  @derive Jason.Encoder
  @derive JSON.Encoder
  defstruct [:id, :ticker, :period, :general, :balance_sheet, :cashflow, :income_statement]

  @type t :: %__MODULE__{
          id: String.t(),
          ticker: String.t(),
          period: String.t(),
          general: General.t(),
          balance_sheet: BalanceSheet.t(),
          cashflow: Cashflow.t(),
          income_statement: IncomeStatement.t()
        }

  def parse(%FundamentalIDX{general: general} = data, period, ticker) do
    [:general, :balance_sheet, :cashflow, :income_statement]
    |> Enum.reduce([id: data.id, ticker: ticker], fn key, acc ->
      rounding = Map.get(general, "rounding", 1) |> parse_rounding()
      metadata = Map.put(data.metadata, "rounding", rounding)

      Map.get(data, key, %{})
      |> parse_item(metadata, {FundamentalIDX, key})
      |> then(fn
        %General{} = acc ->
          Map.put(acc, :period, period)

        mod ->
          Map.put(mod, :name, ticker)
          |> Map.put(:period, period)
      end)
      |> then(&Keyword.put(acc, key, &1))
    end)
    |> Keyword.put_new(:period, period)
    |> then(&struct(__MODULE__, &1))
  end

  def parse(%Factset{} = fs, period, ticker) do
    [:balance_sheet, :cashflow, :income_statement]
    |> Enum.reduce([id: fs.id, ticker: ticker], fn key, acc ->
      Map.put(fs.data, "ticker_exchange", ticker)
      |> parse_item(%{}, {Factset, key})
      |> then(&Keyword.put(acc, key, &1))
    end)
    |> Keyword.put_new(:period, period)
    |> then(&struct(__MODULE__, &1))
  end

  def parse(_rest, _period) do
    :logger.warning("cannot parse into #{__MODULE__}")
    nil
  end

  defp parse_item(data, metadata, {mod, key}) do
    stt = get_fundamental_module(key)
    default = struct(stt)

    apply(mod, :translate, [data, key])
    |> case do
      nil ->
        default

      opts ->
        Map.from_struct(default)
        |> Enum.map(fn {key, _val} ->
          lookup = to_string(key)
          {key, Map.get(opts, lookup, 0)}
        end)
        |> then(&overridable_strategy(&1, metadata, key))
        |> then(&struct(stt, &1))
    end
  end

  defp parse_item(_data, _metadata, _), do: nil

  defp parse_rounding(key) do
    k = String.downcase(key)

    %{"satuan" => 1, "ribuan" => 1000, "jutaan" => 1_000_000, "miliaran" => 1_000_000_000}
    |> Enum.find(fn {d, _} -> String.contains?(k, d) end)
    |> elem(1)
  end

  defp overridable_strategy(res, data, :balance_sheet) do
    ppe_override(res, data)
    |> depreciation_and_amortization_bs_override(data)
    |> standardize_rounding(data)
  end

  defp overridable_strategy(res, data, :income_statement) do
    depreciation_and_amortization_override(res, data)
    |> gross_profit_override()
    |> standardize_rounding(data)
  end

  defp overridable_strategy(res, data, _) do
    res
    |> depreciation_and_amortization_bs_override(data)
    |> standardize_rounding(data)
  end

  defp standardize_rounding(res, data) do
    rounding = Map.get(data, "rounding", 1)

    Enum.map(res, fn
      {key, value} when is_number(value) -> {key, value * rounding}
      {key, value} -> {key, value}
    end)
  end

  defp get_fundamental_module(:balance_sheet), do: BalanceSheet
  defp get_fundamental_module(:cashflow), do: Cashflow
  defp get_fundamental_module(:income_statement), do: IncomeStatement
  defp get_fundamental_module(_), do: General

  defp ppe_override(res, data) do
    Map.get(data, "property_plant_and_equipment", [])
    |> case do
      [head, tail] ->
        Keyword.put(res, :property_plant_equipment, head - tail)

      _ ->
        res
    end
  end

  defp depreciation_and_amortization_bs_override(res, data) do
    Map.get(data, "property_plant_and_equipment", [])
    |> List.last(0)
    |> then(fn
      0 -> res
      r -> Keyword.put(res, :depreciation_and_amortization, r)
    end)
  end

  defp depreciation_and_amortization_override(res, data) do
    Map.get(data, "right_of_use_assets", [])
    |> List.last(0)
    |> then(fn
      r when is_number(r) ->
        Map.get(data, "assets_under_construction", [])
        |> List.last(0)
        |> case do
          num when is_number(num) -> Kernel.+(num, r)
          _ -> r
        end

      _ ->
        Map.get(data, "assets_under_construction", [])
        |> List.last(0)
        |> case do
          n when is_number(n) -> n
          _ -> 0
        end
    end)
    |> then(fn
      0 -> res
      r -> Keyword.put(res, :depreciation_and_amortization, r)
    end)
  end

  defp gross_profit_override(data) do
    case Keyword.get(data, :revenue) do
      0 ->
        data

      num ->
        Keyword.get(data, :cogs, 0)
        |> then(&Keyword.put(data, :gross_profit, num - &1))
    end
  end
end
