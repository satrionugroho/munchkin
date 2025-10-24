defmodule Munchkin.Inventory do
  alias Munchkin.Inventory.FundamentalIDX
  alias Munchkin.Inventory.Fundamental
  alias Munchkin.Repo

  alias Munchkin.Inventory.{
    Asset,
    AssetTicker,
    AssetSource,
    TradeHistory
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

    ~w(balance_sheet income_statement period cashflow ticker general)
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

  defp do_insert_fundamental_data(%{"ticker" => ticker, "period" => period} = params) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:params, fn _repo, _ ->
      Munchkin.Utils.MapString.perform(params)
      |> then(fn p ->
        case Map.get(p, "source_id") do
          nil -> Map.put(params, "source_id", Munchkin.Engine.Jkse.id())
          _ -> params
        end
      end)
      |> then(fn p -> {:ok, Map.put(p, "asset_id", ticker)} end)
    end)
    |> Ecto.Multi.run(:fundamental_exists, fn repo, %{params: %{"source_id" => ref}} ->
      case get_fundamental_by_period(ticker, period, repo: repo, ref_id: ref) do
        nil -> {:ok, nil}
        data -> {:ok, data}
      end
    end)
    |> Ecto.Multi.merge(fn
      %{fundamental_exists: fun, params: params} when is_nil(fun) ->
        Ecto.Multi.new()
        |> Ecto.Multi.run(
          :asset,
          &get_data_from_given_params(&1, %{params: params, left: &2}, "asset", Asset)
        )
        |> Ecto.Multi.run(
          :source,
          &get_data_from_given_params(&1, %{params: params, left: &2}, "source", AssetSource)
        )

      %{fundamental_exists: fun} ->
        Ecto.Multi.new()
        |> Ecto.Multi.put(:source, fun.source)
        |> Ecto.Multi.put(:asset, fun.asset)
    end)
    |> Ecto.Multi.insert(:fundamental, &fundamental_changeset/1)
    |> Ecto.Multi.insert(:channel, &fundamental_channel_changeset/1)
    |> Repo.transact()
  end

  def get_fundamental_by_period(ticker, period, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    ref_id = Keyword.get(opts, :ref_id, Munchkin.Engine.Jkse.id())
    [ticker, exchange] = split_ticker_and_exchange(ticker)

    query =
      from(t in Fundamental,
        inner_join: a in AssetTicker,
        on: a.asset_id == t.asset_id,
        where: a.exchange == ^exchange and a.ticker == ^ticker,
        where: t.period == ^period and t.ref_id == ^ref_id,
        preload: [:asset, :source],
        limit: 1
      )

    repo.one(query)
  end

  defp fundamental_changeset(%{fundamental_exists: fun} = opts) when is_nil(fun) do
    %{params: params, source: source, asset: asset} = opts

    %Fundamental{}
    |> Fundamental.changeset(%{asset: asset, source: source, period: Map.get(params, "period")})
  end

  defp fundamental_changeset(opts) do
    %{params: params, source: source, asset: asset, fundamental_exists: fun} = opts

    options = %{
      "asset" => asset,
      "source" => source,
      "period" => Map.get(params, "period"),
      "parent" => fun,
      "metadata" => %{
        "type" => "revision",
        "revise_at" => DateTime.utc_now(:second) |> DateTime.to_string()
      }
    }

    %Fundamental{}
    |> Fundamental.changeset(options)
  end

  defp fundamental_channel_changeset(%{fundamental: data} = opts) do
    %{params: params} = opts

    %FundamentalIDX{}
    |> FundamentalIDX.changeset(Map.put(params, "id", data.id))
  end

  def get_fundamental(id, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    repo.get(Fundamental, id)
  end

  def get_fundamental_data(ticker, period, opts \\ []) do
    case get_fundamental_by_period(ticker, period, opts) do
      nil ->
        {:error,
         "fundamental data with with ticker #{inspect(ticker)} and period of #{inspect(period)} is not found"}

      f ->
        do_get_fundamental_detail(f, opts)
    end
  end

  defp do_get_fundamental_detail(%{source: %mod{} = source} = fundamental, opts) do
    repo = Keyword.get(opts, :repo, Repo)
    detail_struct = apply(mod, :detail, [source.abbr])

    repo.get(detail_struct, fundamental.id)
    |> case do
      nil -> nil
      data -> Munchkin.Inventory.Fundamental.Schema.parse(data, fundamental.period)
    end
  end
end
