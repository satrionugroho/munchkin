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

  def parse(%FundamentalIDX{general: _general} = data, period, ticker) do
    [:general, :balance_sheet, :cashflow, :income_statement]
    |> Enum.reduce([id: data.id, ticker: ticker], fn key, acc ->
      Map.get(data, key, %{})
      |> parse_item({FundamentalIDX, key})
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
      |> parse_item({Factset, key})
      |> then(&Keyword.put(acc, key, &1))
    end)
    |> Keyword.put_new(:period, period)
    |> then(&struct(__MODULE__, &1))
  end

  def parse(_rest, _period) do
    :logger.warning("cannot parse into #{__MODULE__}")
    nil
  end

  defp parse_item(data, {mod, key}) do
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
        |> then(&struct(stt, &1))
    end
  end

  defp parse_item(_data, _), do: nil

  defp get_fundamental_module(:balance_sheet), do: BalanceSheet
  defp get_fundamental_module(:cashflow), do: Cashflow
  defp get_fundamental_module(:income_statement), do: IncomeStatement
  defp get_fundamental_module(_), do: General
end
