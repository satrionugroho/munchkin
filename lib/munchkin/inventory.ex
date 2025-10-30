defmodule Munchkin.Inventory do
  alias Munchkin.Repo
  alias Munchkin.Inventory.Fundamental
  alias Munchkin.Inventory.Fundamental.Gate

  alias Munchkin.Inventory.{
    Asset,
    AssetTicker,
    AssetSource,
    TradeHistory
  }

  import Ecto.Query, warn: false

  def fundamental_periods do
    ~w(q1 q2 q3 fy)
  end

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
      query = from a in Asset, where: a.id == ^id, preload: [:tickers], limit: 1

      repo.one(query)
    rescue
      ArgumentError ->
        [ticker, exchange] = split_ticker_and_exchange(raw_id_or_ticker)

        ticker_query =
          from t in AssetTicker,
            where: t.exchange == ^exchange and t.ticker == ^ticker,
            select: %{id: t.asset_id},
            limit: 1

        query =
          from a in Asset, where: a.id == subquery(ticker_query), preload: [:tickers], limit: 1

        repo.one(query)
    end
  end

  def create_asset(attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:params, fn _repo, _ ->
      {:ok, Munchkin.Utils.MapString.perform(attrs)}
    end)
    |> Ecto.Multi.run(:source, &Gate.get_data_from_given_params(&1, &2, "source", AssetSource))
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
    |> Ecto.Multi.run(:asset, &Gate.get_data_from_given_params(&1, &2, "asset", Asset))
    |> Ecto.Multi.run(:source, &Gate.get_data_from_given_params(&1, &2, "source", AssetSource))
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

  def insert_fundamentals(%mod{} = data) do
    case mod do
      Munchkin.Engine.Factset.Fundamental -> insert_factset_fundamental(data)
      Munchkin.Engine.Jkse.Fundamental -> insert_jkse_fundamental(data)
      _ -> raise ArgumentError, "not implement the fundamental from #{inspect(mod)}"
    end
  end

  def insert_fundamentals(data) when is_map(data), do: insert_jkse_fundamental(data)

  def insert_fundamentals(data) do
    raise ArgumentError, "cannot insert fundamental with data #{inspect(data)}"
  end

  defp insert_jkse_fundamental(data) do
    keys = Map.keys(data)

    ~w(balance_sheet income_statement period cashflow ticker general)
    |> Enum.all?(&Enum.member?(keys, &1))
    |> case do
      true ->
        Map.put(data, "source_id", Munchkin.Engine.Jkse.id())
        |> then(&Gate.insert_fundamental_data(Munchkin.Inventory.Fundamental.Provider.IDX, &1))

      _ ->
        raise ArgumentError, "Cannot insert fundamental data. missing required keys"
    end
  end

  defp split_ticker_and_exchange(ticker_and_exchange) do
    case String.split(ticker_and_exchange, ~r/\W/) do
      [ticker] -> [ticker, "JK"]
      [ticker, exchange] -> [ticker, exchange]
      [ticker | last] -> [ticker, List.first(last)]
      _ -> raise ArgumentError, "Please provide the correct ticker and exchange"
    end
    |> Enum.map(&String.upcase/1)
  end

  defp rename_factset_ticker_region_to_exchange(ticker_and_region) do
    String.replace(ticker_and_region, "ID", "JK")
  end

  defp insert_factset_fundamental(%{ticker: ticker_and_region, data: data} = _factset_fundamental) do
    ticker = rename_factset_ticker_region_to_exchange(ticker_and_region)
    source_id = Munchkin.Engine.Factset.id()

    Repo.transact(fn ->
      Enum.map(data, fn d ->
        curr_d = Map.get(d, "date") |> Date.from_iso8601!()
        period = fiscal_quarter(curr_d) |> then(&Kernel.<>(to_string(curr_d.year), &1))
        params = %{"source_id" => source_id, "ticker" => ticker, "period" => period, "data" => d}

        Gate.insert_fundamental_data(Munchkin.Inventory.Fundamental.Provider.Factset, params)
      end)
      |> Enum.all?(fn
        {:ok, _data} -> true
        _ -> false
      end)
      |> then(fn
        true -> {:ok, "inserted"}
        _ -> {:error, "there is an error due to insert operation"}
      end)
    end)
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

  def get_fundamental_by_periods(ticker, periods, opts \\ [])

  def get_fundamental_by_periods(ticker_and_exchange, [_ | _] = given_periods, opts) do
    repo = Keyword.get(opts, :repo, Repo)
    periods = parse_periods(given_periods)

    [ticker, exchange] = split_ticker_and_exchange(ticker_and_exchange)

    asset_query =
      from a in AssetTicker,
        where: a.exchange == ^exchange and a.ticker == ^ticker,
        select: [:asset_id],
        limit: 1

    case Keyword.get(opts, :ref_id) do
      nil ->
        from(t in Fundamental,
          where: t.asset_id == subquery(asset_query),
          where: t.period in ^periods,
          order_by: {:desc, :inserted_at},
          preload: [:source, [asset: :tickers]]
        )

      ref_id ->
        from(t in Fundamental,
          where: t.asset_id == subquery(asset_query),
          where: t.period in ^periods and t.ref_id == ^ref_id,
          order_by: {:desc, :inserted_at},
          preload: [:source, [asset: :tickers]]
        )
    end
    |> repo.all()
  end

  def get_fundamental_by_periods(ticker, period, opts),
    do: get_fundamental_by_periods(ticker, [period], opts)

  defp parse_periods([_ | _] = list) do
    Enum.map(list, &parse_periods/1)
    |> :lists.flatten()
  end

  defp parse_periods(p) when is_number(p) do
    curr_date = Date.utc_today()

    year =
      case curr_date.year < p do
        true -> curr_date.year
        _ -> p
      end

    Enum.map(fundamental_periods(), fn period ->
      "#{year}#{period}"
      |> String.upcase()
    end)
  end

  defp parse_periods(p) when is_bitstring(p), do: p

  def get_fundamental(id, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    repo.get(Fundamental, id)
  end

  def get_fundamental_data(ticker, period, opts \\ []) do
    case get_fundamental_by_periods(ticker, period, opts) do
      [_ | _] = f ->
        Enum.group_by(f, & &1.period)
        |> Enum.reduce([], fn {_key, data}, acc ->
          Enum.sort_by(data, & &1.source.priority)
          |> List.first()
          |> then(fn k -> [k | acc] end)
        end)
        |> do_get_fundamental_detail(opts)

      data ->
        IO.inspect(data)

        {:error,
         "fundamental data with with ticker #{inspect(ticker)} and period of #{inspect(period)} is not found"}
    end
  end

  defp do_get_fundamental_detail(data, opts) do
    repo = Keyword.get(opts, :repo, Repo)

    Enum.group_by(data, & &1.source.abbr)
    |> Enum.reduce([], fn {key, groupped}, acc ->
      mod = AssetSource.detail(key)

      get_representative_detail(groupped, mod, repo)
      |> then(fn x -> [x | acc] end)
    end)
    |> :lists.flatten()
  end

  defp get_representative_detail([fun | _rest] = data, mod, repo) do
    ticker = Map.get(fun, :asset) |> Map.get(:tickers) |> parse_asset_tickers()
    ids = Enum.map(data, & &1.id)
    query = from d in mod, where: d.id in ^ids

    repo.all(query)
    |> case do
      nil ->
        nil

      details ->
        Enum.map(details, fn d ->
          period = Enum.find(data, &String.equivalent?(&1.id, d.id)) |> Map.get(:period)
          Munchkin.Inventory.Fundamental.Schema.parse(d, period, ticker)
        end)
    end
  end

  defp parse_asset_tickers([_t | _l] = tickers) do
    Enum.reduce(tickers, "", fn
      ticker, "" -> "#{ticker.ticker}-#{ticker.exchange}"
      _, acc -> acc
    end)
  end

  def fiscal_quarter(%Date{} = date) do
    year = date.year

    %{
      "q1" => Date.range(Date.new!(year, 1, 1), Date.new!(year, 3, 31)),
      "q2" => Date.range(Date.new!(year, 4, 1), Date.new!(year, 6, 30)),
      "q3" => Date.range(Date.new!(year, 7, 1), Date.new!(year, 9, 30))
    }
    |> Enum.reduce("FY", fn {key, range}, acc ->
      case Kernel.in(date, range) do
        true -> String.upcase(key)
        _ -> acc
      end
    end)
  end
end
