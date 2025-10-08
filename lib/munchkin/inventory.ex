defmodule Munchkin.Inventory do
  alias Munchkin.Repo

  alias Munchkin.Inventory.{
    Asset,
    AssetTicker,
    AssetSource,
    TradeHistory,
    BalanceSheet,
    IncomeStatement,
    Cashflow
  }

  import Ecto.Query, warn: false

  def create_asset_source(params \\ %{}) do
    AssetSource
    |> AssetSource.changeset(params)
    |> Repo.insert()
  end

  def get_source(id, opts \\ []) do
    repo = Keyword.get(opts, :repo, Munchkin.Repo)

    repo.get(AssetSource, id)
  end

  def get_asset(raw_id_or_ticker, opts \\ []) do
    repo = Keyword.get(opts, :repo, Munchkin.Repo)

    try do
      id = String.to_integer(raw_id_or_ticker)

      repo.get(Asset, id)
    rescue
      ArgumentError ->
        [ticker, exchange] = split_ticker_and_exchange(raw_id_or_ticker)

        ticker_query =
          from t in AssetTicker,
            where: t.exchange == ^exchange and t.ticker == ^ticker,
            select: %{id: t.asset_id},
            limit: 1

        query =
          from a in Asset,
            inner_lateral_join: c in subquery(ticker_query),
            on: a.id == c.id

        repo.one(query)
    end
  end

  def create_asset(attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:params, fn _repo, _ ->
      {:ok, Munchkin.Utils.MapString.perform(attrs)}
    end)
    |> Ecto.Multi.run(:source, &get_data_from_given_params(&1, &2, "source", AssetSource))
    |> Ecto.Multi.insert(:asset, fn %{params: params} ->
      attrs = Map.drop(params, ["exchange", "source", "source_id", "ticker"])

      %Asset{}
      |> Asset.changeset(attrs)
    end)
    |> Ecto.Multi.insert(:ticker, fn %{source: source, asset: asset, params: params} ->
      %AssetTicker{}
      |> AssetTicker.changeset(%{
        source: source,
        asset: asset,
        ticker: Map.get(params, "ticker"),
        exchange: Map.get(params, "exchange")
      })
    end)
    |> Repo.transact()
  end

  def add_trade_data(attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:params, fn _repo, _ ->
      {:ok, Munchkin.Utils.MapString.perform(attrs)}
    end)
    |> Ecto.Multi.run(:asset, &get_data_from_given_params(&1, &2, "asset", Asset))
    |> Ecto.Multi.run(:source, &get_data_from_given_params(&1, &2, "source", AssetSource))
    |> Ecto.Multi.insert_all(
      :trade_history,
      TradeHistory,
      fn %{
           asset: asset,
           source: source,
           params: params
         } ->
        Map.get(params, "trades", [])
        |> Enum.map(fn data ->
          TradeHistory.changeset(%TradeHistory{}, data)
          |> Map.get(:changes)
          |> Map.merge(%{asset_id: asset.id, ref_id: source.id})
        end)
      end,
      on_conflict: :replace_all,
      conflict_target: [:asset_id, :ref_id, :date]
    )
    |> Repo.transact()
  end

  defp validate_data_with_module(mod, %given{} = data) when mod == given, do: {:ok, data}

  defp validate_data_with_module(mod, data),
    do: {:error, "cannot validate the given data with #{inspect(mod)}, given #{inspect(data)}"}

  defp get_data_from_given_params(repo, opts, type, module) do
    params = Map.get(opts, :params, %{})

    case Map.get(params, type) do
      nil ->
        fun = String.to_existing_atom("get_#{type}")
        id = Map.get(params, "#{type}_id")
        apply(__MODULE__, fun, [id, [repo: repo]])

      data ->
        data
    end
    |> then(&validate_data_with_module(module, &1))
  end

  def get_asset_trade_history(ticker_or_id, opts \\ [])

  def get_asset_trade_history(ticker_and_exchange, opts) do
    limit = Keyword.get(opts, :limit, 100)
    repo = Keyword.get(opts, :repo, Repo)

    try do
      id = String.to_integer(ticker_and_exchange)

      query =
        from t in TradeHistory, where: t.asset_id == ^id, limit: ^limit, order_by: {:desc, :date}

      repo.all(query)
    rescue
      ArgumentError ->
        [ticker, exchange] = split_ticker_and_exchange(ticker_and_exchange)

        ticker_query =
          from t in AssetTicker,
            where: t.exchange == ^exchange and t.ticker == ^ticker,
            select: %{id: t.asset_id},
            limit: 1

        query =
          from(t in TradeHistory,
            inner_lateral_join: a in subquery(ticker_query),
            on: a.id == t.id,
            limit: ^limit,
            order_by: {:desc, :date},
            select: [t]
          )

        repo.all(query)
    end
  end

  def insert_fundamentals(data) do
    keys = Map.keys(data)

    ~w(balance_sheet income_statement period cashflow ticker)
    |> Enum.all?(&Enum.member?(keys, &1))
    |> case do
      true -> do_insert_fundamental_data(data)
      _ -> raise ArgumentError, "Cannot insert fundamental data. missing required keys"
    end
  end

  defp split_ticker_and_exchange(ticker_and_exchange) do
    case String.split(ticker_and_exchange, ":") do
      [ticker] -> [ticker, "JK"]
      [ticker, exchange] -> [ticker, exchange]
      [ticker | last] -> [ticker, List.first(last)]
      _ -> raise ArgumentError, "Please provide the correct ticker and exchange"
    end
    |> Enum.map(&String.upcase/1)
  end

  defp do_insert_fundamental_data(%{"period" => period, "ticker" => ticker} = data) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:params, fn _repo, _ ->
      params = Munchkin.Utils.MapString.perform(data)

      case Map.get(params, "source_id") do
        nil -> Map.put(params, "source_id", Munchkin.Engine.Jkse.id())
        _ -> params
      end
      |> then(fn p -> {:ok, Map.put(p, "asset_id", ticker)} end)
    end)
    |> Ecto.Multi.run(:asset, &get_data_from_given_params(&1, &2, "asset", Asset))
    |> Ecto.Multi.run(:source, &get_data_from_given_params(&1, &2, "source", AssetSource))
    |> Ecto.Multi.insert(:balance_sheet, &fundamental_changeset(&1, BalanceSheet, period))
    |> Ecto.Multi.insert(:income_statement, &fundamental_changeset(&1, IncomeStatement, period))
    |> Ecto.Multi.insert(:cashflow, &fundamental_changeset(&1, Cashflow, period))
    |> Repo.transact()
  end

  defp fundamental_changeset(opts, mod, period) do
    type = apply(mod, :key, [])

    opts
    |> Map.get(:params, %{})
    |> Map.get(type)
    |> translate_fundamental_keys(type)
    |> Map.merge(%{
      "asset" => Map.get(opts, :asset),
      "source" => Map.get(opts, :source),
      "period" => period,
      "yearly" => get_fundamental_yearly(period)
    })
    |> then(fn params ->
      apply(mod, :changeset, [struct(mod), params])
    end)
  end

  defp translate_fundamental_keys(data, type) do
    fun = String.to_existing_atom(type)
    version = Map.get(data, "version")

    case version do
      ver when ver in [nil, ""] ->
        %{}

      _ ->
        apply(Munchkin.JkseToDB, fun, [version])
        |> Enum.reduce(%{}, fn {key, val}, acc ->
          Map.take(data, val)
          |> Map.values()
          |> Enum.sum_by(fn
            nil -> 0
            x -> x
          end)
          |> then(&Map.put(acc, key, &1))
          |> then(
            &Map.merge(&1, Map.take(data, ["filling_date", "ccy", "rounding", "conversion_rate"]))
          )
        end)
    end
  end

  defp get_fundamental_yearly(period) do
    ~w(audit fy)
    |> Enum.map(&String.contains?(String.downcase(period), &1))
    |> Enum.any?()
  end
end
