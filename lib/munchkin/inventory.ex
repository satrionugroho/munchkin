defmodule Munchkin.Inventory do
  alias Munchkin.Repo

  alias Munchkin.Inventory.Fundamental.Gate

  alias Munchkin.Inventory.{
    Analize,
    Asset,
    AssetType,
    AssetTicker,
    AssetSource,
    Fundamental,
    Market,
    Summary,
    TradeHistory,
    Transaction,
    TransactionStatus
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

  def get_asset(id, opts \\ [])

  def get_asset(id, opts) when is_number(id) do
    repo = Keyword.get(opts, :repo, Munchkin.Repo)

    query = from a in Asset, where: a.id == ^id, preload: [:tickers], limit: 1

    repo.one(query)
  end

  def get_asset(raw_id_or_ticker, opts) do
    repo = Keyword.get(opts, :repo, Munchkin.Repo)

    try do
      id = String.to_integer(raw_id_or_ticker)
      get_asset(id, repo: repo)
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

  def get_multiple_assets(ids, opts \\ []) do
    repo = Keyword.get(opts, :repo, Munchkin.Repo)

    query =
      case Keyword.get(opts, :keyword) do
        kw when is_bitstring(kw) ->
          from a in Asset,
            join: t in AssetTicker,
            on: t.asset_id == a.id,
            preload: [:tickers],
            where: a.id in ^ids,
            where: ilike(a.name, ^"%#{kw}%") or ilike(t.ticker, ^"%#{kw}%")

        _ ->
          from a in Asset, preload: [:tickers], where: a.id in ^ids
      end

    repo.all(query)
  end

  def get_index(ticker_or_id, opts \\ []) do
    repo = Keyword.get(opts, :repo, Munchkin.Repo)

    try do
      id = String.to_integer(ticker_or_id)

      query =
        from a in Asset, where: a.id == ^id and a.type_id == :index, preload: [:tickers], limit: 1

      repo.one(query)
    rescue
      ArgumentError ->
        ticker_query =
          from t in AssetTicker,
            where: t.ticker == ^ticker_or_id,
            select: %{id: t.asset_id},
            limit: 1

        query =
          from a in Asset,
            where: a.id == subquery(ticker_query) and a.type_id == :index,
            preload: [:tickers],
            limit: 1

        repo.one(query)
    end
  end

  def create_asset(attrs, opts \\ []) do
    repo = Keyword.get(opts, :repo, Munchkin.Repo)

    Ecto.Multi.new()
    |> Ecto.Multi.run(:params, fn _repo, _ ->
      Munchkin.Utils.MapString.perform(attrs)
      |> Map.put_new("source_id", Munchkin.Engine.Jkse.id())
      |> then(fn p -> {:ok, p} end)
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
    |> repo.transact()
  end

  def add_trade_data(attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:params, fn _repo, _ ->
      Munchkin.Utils.MapString.perform(attrs)
      |> then(fn p ->
        ticker = Map.get(p, "ticker")

        Map.put_new(p, "source_id", Munchkin.Engine.Jkse.id())
        |> Map.put("asset_id", ticker)
      end)
      |> then(fn p -> {:ok, p} end)
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
    limit = Keyword.get(opts, :limit, 1000)
    repo = Keyword.get(opts, :repo, Repo)
    type_id = Keyword.get(opts, :type)
    start_date = Keyword.get(opts, :start_date)
    default_fields = TradeHistory.__schema__(:fields)
    fields = Keyword.get(opts, :fields, default_fields)

    try do
      id = String.to_integer(ticker_and_exchange)

      query =
        case start_date do
          nil ->
            from t in TradeHistory,
              where: t.asset_id == ^id,
              limit: ^limit,
              order_by: {:desc, :date}

          date ->
            from t in TradeHistory,
              where: t.asset_id == ^id and t.date >= ^date,
              order_by: {:desc, :date}
        end

      case Keyword.get(opts, :output) do
        :sql ->
          repo.to_sql(:all, from(q in query, select: ^fields))

        :map ->
          repo.all(from(q in query, select: map(q, ^fields)))

        _ ->
          repo.all(from(q in query, select: ^fields))
      end
    rescue
      ArgumentError ->
        [ticker, exchange] = split_ticker_and_exchange(ticker_and_exchange)

        base_query =
          from t in AssetTicker,
            where: t.exchange == ^exchange and t.ticker == ^ticker,
            limit: 1

        ticker_query =
          case type_id do
            nil ->
              from(b in base_query, select: %{id: b.asset_id})

            id ->
              from b in base_query,
                join: a in Munchkin.Inventory.Asset,
                on: a.id == b.asset_id,
                where: a.type_id == ^id,
                select: %{id: b.asset_id}
          end

        query =
          case start_date do
            nil ->
              from(t in TradeHistory,
                where: t.asset_id == subquery(ticker_query),
                limit: ^limit,
                order_by: {:desc, :date}
              )

            date ->
              from t in TradeHistory,
                where: t.asset_id == subquery(ticker_query) and t.date >= ^date,
                order_by: {:desc, :date}
          end

        case Keyword.get(opts, :output) do
          :sql ->
            repo.to_sql(:all, from(q in query, select: ^fields))

          :map ->
            repo.all(from(q in query, select: map(q, ^fields)))

          _ ->
            repo.all(from(q in query, select: ^fields))
        end
    end
  end

  def get_last_trade_history(ticker_asset_or_id, opts \\ [])
  def get_last_trade_history(%Asset{} = asset, opts), do: get_last_trade_history(asset.id, opts)

  def get_last_trade_history(asset_id, opts) when is_integer(asset_id) do
    repo = Keyword.get(opts, :repo, Munchkin.Repo)

    query =
      from t in TradeHistory, where: t.asset_id == ^asset_id, limit: 1, order_by: {:desc, :date}

    repo.one(query)
  end

  def get_last_trade_history(ticker_or_id, opts) do
    try do
      id = String.to_integer(ticker_or_id)
      get_last_trade_history(id, opts)
    rescue
      ArgumentError ->
        repo = Keyword.get(opts, :repo, Repo)
        type_id = Keyword.get(opts, :type)
        [ticker, exchange] = split_ticker_and_exchange(ticker_or_id)

        base_query =
          from t in AssetTicker,
            where: t.exchange == ^exchange and t.ticker == ^ticker,
            limit: 1

        ticker_query =
          case type_id do
            nil ->
              from(b in base_query, select: %{id: b.asset_id})

            id ->
              from b in base_query,
                join: a in Munchkin.Inventory.Asset,
                on: a.id == b.asset_id,
                where: a.type_id == ^id,
                select: %{id: b.asset_id}
          end

        query =
          from t in TradeHistory,
            where: t.asset_id == subquery(ticker_query),
            limit: 1,
            order_by: {:desc, :date}

        repo.one(query)
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
    [ticker, exchange] = split_ticker_and_exchange(ticker)

    query =
      case Keyword.get(opts, :ref_id) do
        nil ->
          from(t in Fundamental,
            inner_join: a in AssetTicker,
            on: a.asset_id == t.asset_id,
            where: a.exchange == ^exchange and a.ticker == ^ticker,
            where: t.period == ^period,
            preload: [:source, [asset: :tickers]],
            limit: 1
          )

        ref_id ->
          from(t in Fundamental,
            inner_join: a in AssetTicker,
            on: a.asset_id == t.asset_id,
            where: a.exchange == ^exchange and a.ticker == ^ticker,
            where: t.period == ^period and t.ref_id == ^ref_id,
            preload: [:source, [asset: :tickers]],
            limit: 1
          )
      end

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

    case Ecto.UUID.cast(id) do
      {:ok, _} -> repo.get(Fundamental, id)
      _ -> get_fundamental_by_ticker(id, repo)
    end
  end

  defp get_fundamental_by_ticker(id, repo) do
    query =
      from f in Fundamental,
        join: a in AssetTicker,
        on: f.asset_id == a.asset_id,
        preload: [:source, :tickers]

    repo.all(query)
  end

  def get_fundamental_data(ticker, period, opts \\ [])

  def get_fundamental_data(ticker, [_ | _] = periods, opts) do
    Enum.map(periods, &fundamental_data_periods/1)
    |> :lists.flatten()
    |> then(fn standardize_p ->
      get_fundamental_by_periods(ticker, standardize_p, opts)
      |> do_get_fundamental_detail(opts)
    end)
    |> Enum.sort_by(& &1.period)
  end

  def get_fundamental_data(ticker, period, opts) when is_number(period) do
    fundamental_data_periods(period)
    |> :lists.flatten()
    |> then(&get_fundamental_data(ticker, &1, opts))
    |> Enum.sort_by(& &1.period)
  end

  def get_fundamental_data(ticker, period, opts), do: get_fundamental_data(ticker, [period], opts)

  defp fundamental_data_periods(year) when is_number(year), do: parse_periods(year)

  defp fundamental_data_periods(string_year) when is_bitstring(string_year) do
    try do
      year = String.to_integer(string_year)
      fundamental_data_periods(year)
    rescue
      ArgumentError -> [string_year]
    end
  end

  def fundamental_data_standardization(fun, opts \\ [])

  def fundamental_data_standardization(%Fundamental{} = data, opts) do
    do_get_fundamental_detail(data, opts)
    |> List.first()
  end

  def fundamental_data_standardization(_, _), do: {:error, "please parse from fundamental schema"}

  defp do_get_fundamental_detail(data, opts) when is_list(data) do
    repo = Keyword.get(opts, :repo, Repo)

    Enum.group_by(data, & &1.source.abbr)
    |> Enum.reduce([], fn {key, groupped}, acc ->
      mod = AssetSource.detail(key)

      get_representative_detail(groupped, mod, repo)
      |> then(fn x -> [x | acc] end)
    end)
    |> :lists.flatten()
  end

  defp do_get_fundamental_detail(%Fundamental{} = data, opts) do
    repo = Keyword.get(opts, :repo, Repo)
    mod = AssetSource.detail(data.source)
    get_representative_detail([data], mod, repo)
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

  def beta_calculation(stock, index \\ "COMPOSITE", opts \\ []) do
    shift_year = Keyword.get(opts, :period, 2) |> Kernel.*(-1)
    start_date = Date.utc_today() |> Date.shift(year: shift_year)
    mode = Keyword.get(opts, :mode, "log_return")

    stock_data =
      get_asset_trade_history(stock,
        type_id: Munchkin.Inventory.AssetType.stock(),
        start_date: start_date
      )

    index_data =
      get_asset_trade_history(index,
        type_id: Munchkin.Inventory.AssetType.index(),
        start_date: start_date
      )

    stock_df =
      Enum.map(stock_data, &Map.take(&1, [:close, :date])) |> Munchkin.Calculation.dataframe()

    index_df =
      Enum.map(index_data, &Map.take(&1, [:close, :date])) |> Munchkin.Calculation.dataframe()

    Munchkin.Calculation.beta_calculation(stock_df, index_df, mode)
  end

  def dcf_parameter(stock, index, opts \\ []) do
    risk_free_rate = Keyword.get(opts, :risk_free_rate, 0.04)
    market_risk = Keyword.get(opts, :market_risk, 0.05)
    cost_of_debt = Keyword.get(opts, :cost_of_debt, 0.05)
    tax_rate = Keyword.get(opts, :corporate_tax_rate, 0.2)
    type = Keyword.get(opts, :type, "fcf")
    growth_rate = Keyword.get(opts, :growth_rate, 0.08)
    terminal_growth_rate = Keyword.get(opts, :terminal_growth_rate, 0.025)
    forecast_period = Keyword.get(opts, :forecast_period, 5)
    beta = beta_calculation(stock, index)

    cost_of_equity = risk_free_rate + (beta + market_risk)

    today = Date.utc_today()

    range =
      Range.new(Date.shift(today, year: -1).year, today.year) |> Enum.map(fn y -> "#{y}FY" end)

    latest_fundamental =
      get_fundamental_by_periods(stock, range)
      |> List.first()
      |> do_get_fundamental_detail([])
      |> List.first()

    latest_balance_sheet = Map.get(latest_fundamental, :balance_sheet)
    shareholders_equity = Map.get(latest_balance_sheet, :shareholders_equity_in_company)
    total_liabilities = Map.get(latest_balance_sheet, :total_liabilities)

    total_value = shareholders_equity + total_liabilities
    weight_equity = shareholders_equity / total_value
    weight_debt = total_liabilities / total_value
    wacc = weight_equity * cost_of_equity + weight_debt * cost_of_debt * (1 - tax_rate)

    cf_projections =
      Range.new(1, forecast_period)
      |> Enum.reduce([], fn year, acc ->
        current_cf = calculate_current_cashflow(latest_fundamental, type, year, growth_rate)
        present_value = current_cf / :math.pow(1 + wacc, year)

        [%{year: year, fcf: current_cf, present_value: present_value} | acc]
      end)
      |> Enum.sort_by(&Map.get(&1, :year))

    terminal_fcf =
      List.last(cf_projections) |> Map.get(:fcf) |> Kernel.*(1 + terminal_growth_rate)

    terminal_val = terminal_fcf / (wacc - terminal_growth_rate)
    present_val_term = terminal_val / :math.pow(1 + wacc, forecast_period)
    present_cf = Enum.sum_by(cf_projections, &Map.get(&1, :present_value))

    net_debt =
      latest_balance_sheet.short_term_debt + latest_balance_sheet.long_term_debt -
        latest_balance_sheet.cash_equivalent

    enterprise_val = present_cf + present_val_term
    fair_val = enterprise_val - net_debt

    %{
      discount_rate: wacc,
      enterprise_val: enterprise_val,
      net_debt: net_debt,
      fair_value: fair_val,
      terminal_fcf: terminal_fcf,
      terminal_val: terminal_val,
      present_val_term: present_val_term,
      present_cf: present_cf
    }
  end

  defp calculate_current_cashflow(fundamental, "fcf", year, growth_rate) do
    case Map.get(fundamental, :cashflow) do
      nil -> 0
      cf -> cf.net_cash_operating - cf.capex * -1
    end
    |> then(fn fcf ->
      Range.new(1, year)
      |> Enum.reduce(fcf, fn _, acc ->
        acc = acc * (1 + growth_rate)
        acc
      end)
    end)
  end

  defp calculate_current_cashflow(_, _, _, _), do: 0

  def last_available_fundamental_data(ticker_or_id, type \\ "FY", opts \\ []) do
    t = String.downcase(type)
    repo = Keyword.get(opts, :repo, Munchkin.Repo)
    valid_type = Enum.find(fundamental_periods(), "fy", &Kernel.==(&1, t)) |> String.upcase()
    period_clause = "%#{valid_type}"

    try do
      id = String.to_integer(ticker_or_id)

      query =
        from f in Fundamental,
          where: f.asset_id == ^id and ilike(f.period, ^period_clause),
          order_by: {:desc, f.period},
          limit: 1

      repo.one(query)
    rescue
      ArgumentError ->
        [ticker, exchange] = split_ticker_and_exchange(ticker_or_id)

        base_query =
          from t in AssetTicker,
            select: [:asset_id],
            where: t.exchange == ^exchange and t.ticker == ^ticker,
            limit: 1

        query =
          from f in Fundamental,
            where: f.asset_id == subquery(base_query) and ilike(f.period, ^period_clause),
            order_by: {:desc, f.period},
            limit: 1

        repo.one(query)
    end
  end

  def market_capital(ticker_or_id, opts \\ []) do
    type_id = Keyword.get(opts, :type)
    [ticker, exchange] = split_ticker_and_exchange(ticker_or_id)

    base_query =
      from t in AssetTicker,
        where: t.exchange == ^exchange and t.ticker == ^ticker,
        limit: 1

    ticker_query =
      case type_id do
        nil ->
          from(b in base_query, select: %{id: b.asset_id})

        id ->
          from b in base_query,
            join: a in Munchkin.Inventory.Asset,
            on: a.id == b.asset_id,
            where: a.type_id == ^id,
            select: %{id: b.asset_id}
      end

    query =
      from(t in TradeHistory,
        group_by: fragment("DATE_PART(?, ?)", "month", t.date),
        group_by: [t.date, t.close, t.shares],
        where:
          t.asset_id == subquery(ticker_query) and
            fragment("DATE_PART(?, ?) = ?", "month", t.date, 12),
        having: fragment("DATE_PART(?, ?)", "day", t.date) > 26,
        order_by: {:asc, :date},
        select: {t.close, t.shares, t.date}
      )

    Repo.all(query)
    |> Enum.group_by(&elem(&1, 2).year)
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      {price, shares, _} = List.last(v)

      Map.put(acc, k, %{
        price: Decimal.to_integer(price),
        shares: Decimal.to_integer(shares),
        market_capital: Decimal.mult(price, shares) |> Decimal.to_float()
      })
    end)
  end

  def analize(user, params) do
    %Analize{}
    |> Analize.changeset(%{user: user, analizers: params})
    |> Repo.insert()
  end

  def get_analize_result(id, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    query = from s in Analize, where: s.id == ^id, limit: 1
    repo.one(query)
  end

  def create_summary(opts \\ %{}) do
    with id when not is_nil(id) <- Map.get(opts, "key"),
         sanitized_params <- Map.drop(opts, ["key"]),
         analizer when not is_nil(analizer) <- get_analize_result(id),
         params <- compose_summary_params(analizer, sanitized_params),
         nil <- get_summary_from_params(analizer, params),
         summary <- do_create_summary(analizer, params) do
      {:ok, summary}
    else
      [%Summary{} = summary, %Analize{} = analizer] ->
        case tied_analizer_to_summary(analizer, summary) do
          {:ok, _} -> {:ok, summary}
          err -> err
        end

      err ->
        err
    end
  end

  defp compose_summary_params(%Analize{} = analizer, params) do
    %{
      spec: params,
      analizer: analizer.analizers
    }
  end

  defp get_summary_from_params(analize, params) do
    params
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> get_summary()
    |> then(&[&1, analize])
  end

  defp do_create_summary(%Analize{} = analizer, params) do
    Repo.transact(fn ->
      %Summary{}
      |> Summary.changeset(%{params: params})
      |> Repo.insert()
      |> case do
        {:ok, struct} ->
          case tied_analizer_to_summary(analizer, struct) do
            {:ok, _} -> {:ok, struct}
            err -> err
          end

        _ ->
          :ok
      end
    end)
  end

  defp tied_analizer_to_summary(analizer, summary) do
    Ecto.Changeset.change(analizer, summary_id: summary.hex)
    |> Repo.update()
  end

  def get_summary(id, opts \\ [])

  def get_summary(id, opts) when is_binary(id) do
    repo = Keyword.get(opts, :repo, Repo)
    query = from s in Summary, where: s.hex == ^id, limit: 1
    repo.one(query)
  end

  def get_summary(id, _result) do
    {:error, "cannot get summary with specification #{inspect(id)}"}
  end

  def get_all_tickers() do
    Repo.all(AssetTicker)
  end

  def insert_daily_asset_data(data, date, opts \\ [])
  def insert_daily_asset_data([], _date, _opts), do: {:error, "cannot insert empty data"}

  def insert_daily_asset_data(data, date, opts) when is_bitstring(date) do
    case Date.from_iso8601(date) do
      {:ok, d} -> insert_daily_asset_data(data, d, opts)
      _ -> {:error, "cannot parse date"}
    end
  end

  def insert_daily_asset_data([_ | _] = data, %Date{} = date, opts) do
    type = Keyword.get(opts, :type, "stock")

    assets =
      Repo.all(
        from t in AssetTicker,
          join: a in Asset,
          on: t.asset_id == a.id,
          select: {t.asset_id, t.ticker},
          where: t.exchange == "JK" and a.type_id == ^type
      )

    stabilize_assets(assets, data, type)
    |> do_perform_daily_asset_data(data, date)
  end

  defp stabilize_assets(current_assets, data, type) do
    tickers = Enum.map(data, &Map.get(&1, "ticker"))
    avail_tickers = Enum.map(current_assets, &elem(&1, 1))

    Enum.reduce(tickers, current_assets, fn ticker, acc ->
      case Enum.member?(avail_tickers, ticker) do
        false -> [should_create_asset(ticker, type) | acc]
        _ -> acc
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp stabilize_assets_params(ticker, "index") do
    %{"name" => ticker}
  end

  defp stabilize_assets_params(ticker, _type) do
    Munchkin.Engine.Jkse.Company.profile(ticker)
  end

  defp should_create_asset(ticker, type) do
    stabilize_assets_params(ticker, type)
    |> Map.put("ticker", ticker)
    |> Map.put("type_id", type)
    |> Map.put("exchange", "JK")
    |> create_asset()
    |> case do
      {:ok, %{ticker: ticker}} -> {ticker.asset_id, ticker.ticker}
      _ -> nil
    end
  end

  defp daily_asset_data_asset_finder(assets, ticker) do
    Enum.find(assets, fn {_id, t} -> ticker == t end)
    |> case do
      {id, _} -> id
      _ -> nil
    end
  end

  defp get_frequency(f) do
    try do
      Decimal.to_integer(f)
    rescue
      FunctionClauseError ->
        nil
    end
  end

  defp do_perform_daily_asset_data(assets, data, date) do
    Enum.map(data, fn %{"ticker" => ticker} = d ->
      %{
        open: Map.get(d, "open"),
        high: Map.get(d, "high"),
        low: Map.get(d, "low"),
        close: Map.get(d, "close"),
        volume: Map.get(d, "volume"),
        shares: Map.get(d, "shares"),
        ask: Map.get(d, "ask"),
        ask_volume: Map.get(d, "ask_volume"),
        bid: Map.get(d, "bid"),
        bid_volume: Map.get(d, "bid_volume"),
        frequency: Map.get(d, "frequency") |> get_frequency(),
        ref_id: Munchkin.Engine.Jkse.id(),
        date: date,
        asset_id: daily_asset_data_asset_finder(assets, ticker)
      }
    end)
    |> Enum.reject(fn %{asset_id: a} -> is_nil(a) end)
    |> then(
      &Repo.insert_all(TradeHistory, &1,
        conflict_target: [:date, :asset_id, :ref_id],
        on_conflict: :replace_all
      )
    )
  end

  def transform_ticker(maybe_ticker_and_region, opts \\ []) do
    [ticker, exchange] = split_ticker_and_exchange(maybe_ticker_and_region)

    case Keyword.get(opts, :to) do
      :factset -> rename_ticker_to_factset(ticker, exchange)
      :trading_view -> rename_ticker_to_trading_view(ticker, exchange, opts)
      _ -> "#{ticker}.#{exchange}"
    end
  end

  defp change_factset_region(region) do
    case region do
      "JK" -> "ID"
      _ -> region
    end
  end

  defp change_trading_view_region(region) do
    case region do
      "JK" -> "IDX"
      _ -> region
    end
  end

  defp rename_ticker_to_factset(ticker, region), do: "#{ticker}.#{change_factset_region(region)}"

  defp rename_ticker_to_trading_view(ticker, region, opts) do
    case Keyword.get(opts, :symbol) do
      true -> "#{change_trading_view_region(region)}:#{ticker}"
      _ -> "#{change_trading_view_region(region)}-#{ticker}"
    end
  end

  def insert_market(params, opts \\ []) do
    repo = Keyword.get(opts, :repo, Munchkin.Repo)

    %Market{}
    |> Market.changeset(params)
    |> repo.insert()
  end

  def get_market(id, opts \\ []) do
    repo = Keyword.get(opts, :repo, Munchkin.Repo)

    repo.get(Market, id)
  end

  def get_available_market(opts \\ []) do
    Munchkin.Cache.get_or_update_with_ttl(
      "available_market",
      fn ->
        repo = Keyword.get(opts, :repo, Munchkin.Repo)
        limit = Keyword.get(opts, :limit, 10)
        offset = Keyword.get(opts, :offset, 0)
        query = from m in Market, limit: ^limit, offset: ^offset

        repo.all(query)
        |> then(fn x -> {:ok, x} end)
      end,
      :timer.minutes(5)
    )
  end

  def search_ticker(ticker, opts \\ []) do
    repo = Keyword.get(opts, :repo, Munchkin.Repo)

    query =
      from a in Asset,
        join: t in AssetTicker,
        on: t.asset_id == a.id,
        where: a.type_id == ^AssetType.stock(),
        where: ilike(t.ticker, ^"%#{ticker}%") or ilike(a.name, ^"%#{ticker}%"),
        select: %{
          id: a.id,
          name: a.name,
          ticker: t.ticker,
          exchange: t.exchange,
          default_market: t.market_id
        }

    repo.all(query)
  end

  def add_transactions(params, opts \\ []) do
    repo = Keyword.get(opts, :repo, Munchkin.Repo)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:transaction, Transaction.changeset(%Transaction{}, params))
    |> Ecto.Multi.run(:updated_trx, fn
      repo, %{transaction: %{transaction_type: type} = trx} when type.key == :sell ->
        align_transaction(repo, trx, params)

      _, %{transaction: trx} ->
        {:ok, trx}
    end)
    |> Ecto.Multi.run(:remove_cache, fn _repo, %{transaction: trx} ->
      Munchkin.Cache.delete("total_trx_#{trx.user_id}")
      Munchkin.Cache.delete("total_amount_trx_#{trx.user_id}")
      {:ok, :clear}
    end)
    |> repo.transact()
  end

  defp align_transaction(repo, %{status: %{key: :executed}} = transaction, %{
         "sell_method" => "lifo"
       }) do
    value = transaction.quantity * transaction.price

    get_user_per_asset_transaction(transaction.user_id, transaction.asset_id,
      repo: repo,
      type: :buy
    )
    |> Enum.sort_by(& &1.inserted_at, :desc)
    |> Enum.reduce(
      {transaction.quantity, [], value},
      &quantity_transaction_subtraction(&1, &2, repo)
    )
    |> then(fn {_, trxs, value} ->
      related = [transaction.id | trxs]

      Munchkin.Accounts.add_user_realizations(
        %{
          user_id: transaction.user_id,
          asset_id: transaction.asset_id,
          related_transactions: related,
          value: value
        },
        repo: repo
      )
    end)
  end

  defp align_transaction(repo, %{status: %{key: :executed}} = transaction, %{
         "sell_method" => "fifo"
       }) do
    value = transaction.quantity * transaction.price

    get_user_per_asset_transaction(transaction.user_id, transaction.asset_id,
      repo: repo,
      type: :buy
    )
    |> Enum.sort_by(& &1.inserted_at, :asc)
    |> Enum.reduce(
      {transaction.quantity, [], value},
      &quantity_transaction_subtraction(&1, &2, repo)
    )
    |> then(fn {_, trxs, value} ->
      related = [transaction.id | trxs]

      Munchkin.Accounts.add_user_realizations(
        %{
          user_id: transaction.user_id,
          asset_id: transaction.asset_id,
          related_transactions: related,
          value: value
        },
        repo: repo
      )
    end)
  end

  defp align_transaction(_repo, _transaction, _) do
    {:ok, "not updated"}
  end

  defp quantity_transaction_subtraction(_transaction, 0, _repo), do: 0

  defp quantity_transaction_subtraction(transaction, {qty, acc, pnl}, repo) do
    transaction.current_quantity
    |> Kernel.-(qty)
    |> case do
      num when num > 0 ->
        Transaction.subtract_quantity(transaction, num)
        |> repo.update()
        |> case do
          {:ok, trx} ->
            min = trx.quantity * trx.price
            {num, [trx.id | acc], pnl - min}

          _ ->
            {qty, acc, pnl}
        end

      num ->
        Transaction.subtract_quantity(transaction, transaction.quantity)
        |> repo.update()
        |> case do
          {:ok, trx} ->
            min = trx.quantity * trx.price
            {abs(num), [trx.id | acc], pnl - min}

          _ ->
            {qty, acc, pnl}
        end
    end
  end

  def get_user_transactions(user_or_id, opts \\ [])

  def get_user_transactions(%Munchkin.Accounts.User{} = user, opts),
    do: get_user_transactions(user.id, opts)

  def get_user_transactions(user_id, opts) do
    repo = Keyword.get(opts, :repo, Munchkin.Repo)
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    query =
      case Keyword.get(opts, :status) do
        status when status in ["ongoing", "pending", "executed", "queue"] ->
          from t in Transaction,
            where: t.user_id == ^user_id,
            where: t.status == ^status,
            limit: ^limit,
            offset: ^offset,
            order_by: {:desc, t.inserted_at},
            preload: [:asset]

        _ ->
          from t in Transaction,
            where: t.user_id == ^user_id,
            limit: ^limit,
            offset: ^offset,
            order_by: {:desc, t.inserted_at},
            preload: [:asset]
      end

    repo.all(query)
  end

  def get_user_specific_asset_transactions(user_or_id, asset_or_id, opts \\ [])

  def get_user_specific_asset_transactions(%Munchkin.Accounts.User{} = user, asset_or_id, opts),
    do: get_user_specific_asset_transactions(user.id, asset_or_id, opts)

  def get_user_specific_asset_transactions(user, %Asset{} = asset, opts),
    do: get_user_specific_asset_transactions(user, asset.id, opts)

  def get_user_specific_asset_transactions(user_id, asset_id, opts) do
    repo = Keyword.get(opts, :queue, Munchkin.Repo)

    query =
      from t in Transaction,
        where: t.user_id == ^user_id and t.asset_id == ^asset_id,
        where: t.status == :executed and t.transaction_type == :buy,
        preload: [asset: :tickers]

    repo.all(query)
  end

  def get_total_user_transactions(user_or_id, opts \\ [])

  def get_total_user_transactions(%Munchkin.Accounts.User{} = user, opts),
    do: get_total_user_transactions(user.id, opts)

  def get_total_user_transactions(user_id, opts) do
    Munchkin.Cache.get_or_update_with_ttl(
      "total_trx_#{user_id}",
      fn ->
        repo = Keyword.get(opts, :repo, Munchkin.Repo)

        query =
          from t in Transaction,
            group_by: t.status,
            where: t.user_id == ^user_id,
            select: %{status: t.status, total: count(t.id)}

        result = repo.all(query)

        TransactionStatus.all()
        |> Enum.map(fn f ->
          Enum.find(result, fn %{status: s} ->
            s.id == f.id
          end)
          |> case do
            nil -> 0
            data -> Map.get(data, :total, 0)
          end
          |> then(fn x -> {to_string(f.key), x} end)
        end)
        |> Enum.into(%{})
        |> then(fn x -> {:ok, x} end)
      end,
      :timer.hours(1)
    )
  end

  def get_current_month_amount_user_transactions(user_or_id, opts \\ [])

  def get_current_month_amount_user_transactions(%Munchkin.Accounts.User{} = user, opts),
    do: get_current_month_amount_user_transactions(user.id, opts)

  def get_current_month_amount_user_transactions(user_id, opts) do
    Munchkin.Cache.get_or_update_with_ttl(
      "total_amount_trx_#{user_id}",
      fn ->
        now = Date.utc_today()
        tz = "Etc/UTC"
        start = DateTime.new!(Date.beginning_of_month(now), ~T[00:00:00], tz)
        date_end = DateTime.new!(Date.end_of_month(now), ~T[23:59:59], tz)

        repo = Keyword.get(opts, :repo, Munchkin.Repo)

        query =
          from t in Transaction,
            where: t.user_id == ^user_id,
            where: t.transaction_type == ^Munchkin.Inventory.TransactionType.buy(),
            where: t.status == ^Munchkin.Inventory.TransactionStatus.executed(),
            where: fragment("? BETWEEN ? AND ?", t.settlement_date, ^start, ^date_end),
            select: sum(t.quantity * t.price)

        repo.one(query)
        |> then(fn
          x when is_number(x) -> {:ok, x}
          _ -> {:error, "cannot get user current amount transactions"}
        end)
      end,
      :timer.hours(1)
    )
  end

  def get_user_per_asset_transaction(user_or_id, asset_id, opts \\ [])

  def get_user_per_asset_transaction(%Munchkin.Accounts.User{} = user, asset_id, opts),
    do: get_user_per_asset_transaction(user.id, asset_id, opts)

  def get_user_per_asset_transaction(user_or_id, %Munchkin.Inventory.Asset{} = asset, opts),
    do: get_user_per_asset_transaction(user_or_id, asset.id, opts)

  def get_user_per_asset_transaction(user_id, asset_id, opts) do
    repo = Keyword.get(opts, :repo, Munchkin.Repo)

    query =
      case Keyword.get(opts, :type) do
        :buy ->
          from t in Transaction,
            where: t.user_id == ^user_id and t.asset_id == ^asset_id,
            where: t.transaction_type == ^Munchkin.Inventory.TransactionType.buy(),
            order_by: :inserted_at

        :sell ->
          from t in Transaction,
            where: t.user_id == ^user_id and t.asset_id == ^asset_id,
            where: t.transaction_type == ^Munchkin.Inventory.TransactionType.sell(),
            order_by: :inserted_at

        _ ->
          from t in Transaction,
            where: t.user_id == ^user_id and t.asset_id == ^asset_id,
            order_by: :inserted_at
      end

    repo.all(query)
  end

  def set_transaction_settlement(trx, params) do
    ref = Map.get(params, "reference_id")

    Ecto.Multi.new()
    |> Ecto.Multi.update(
      :transaction,
      Transaction.settlement_changeset(trx, %{reference_id: ref})
    )
    |> Ecto.Multi.run(:updated_trx, fn
      repo, %{transaction: %{transaction_type: type} = trx} when type.key == :sell ->
        align_transaction(repo, trx, params)

      _, %{transaction: trx} ->
        {:ok, trx}
    end)
    |> Repo.transact()
  end

  def user_portfolio(user_or_id, opts \\ [])
  def user_portfolio(%Munchkin.Accounts.User{} = user, opts), do: user_portfolio(user.id, opts)

  def user_portfolio(user_id, opts) do
    repo = Keyword.get(opts, :repo, Munchkin.Repo)

    query =
      from t in Transaction,
        preload: [:asset],
        where: t.user_id == ^user_id,
        where: t.status == ^Munchkin.Inventory.TransactionStatus.executed(),
        where: t.current_quantity != 0,
        where: t.transaction_type == ^Munchkin.Inventory.TransactionType.buy()

    repo.all(query)
    |> get_current_portfolio_price(opts)
  end

  defp get_current_portfolio_price([], _), do: {:ok, 0}

  defp get_current_portfolio_price(data, opts) do
    repo = Keyword.get(opts, :repo, Munchkin.Repo)
    assets = Enum.map(data, & &1.asset_id)

    query =
      from t in TradeHistory,
        where: t.asset_id in ^assets,
        order_by: {:desc, t.date},
        limit: ^length(assets)

    repo.all(query)
    |> calculate_current_portfolio(data, opts)
    |> Enum.into(%{})
    |> then(fn p -> {:ok, p} end)
  end

  defp calculate_current_portfolio(market_data, transactions, opts) do
    Enum.group_by(transactions, & &1.asset_id)
    |> Enum.map(fn {asset_id, trxs} ->
      current_price = Enum.find(market_data, &Kernel.==(&1.asset_id, asset_id))
      {asset_id, calculate_one_asset_portfolio(trxs, current_price)}
    end)
  end

  defp calculate_one_asset_portfolio(transactions, latest_price) do
    Enum.reduce(transactions, %{}, fn trx, acc ->
      curr_qty = Map.get(acc, :quantity, Decimal.new(0))
      curr_avg = Map.get(acc, :average_price, Decimal.new(0))

      new_qty = Decimal.add(curr_qty, trx.current_quantity)

      new_val =
        Decimal.mult(curr_qty, curr_avg)
        |> then(fn last_val ->
          Decimal.mult(trx.quantity, trx.price)
          |> Decimal.add(last_val)
        end)

      new_price = Decimal.div(new_val, new_qty)

      %{
        quantity: new_qty,
        asset_value: new_val,
        average_price: new_price
      }
    end)
    |> then(fn %{quantity: qty, asset_value: asset_value} = res ->
      current_value = Decimal.mult(qty, latest_price.close)

      Map.put(res, :current_value, current_value)
      |> Map.put(:estimated_pnl, Decimal.sub(current_value, asset_value))
    end)
  end

  def change_transaction(%Transaction{} = trx, attrs \\ %{}) do
    Transaction.changeset(trx, attrs)
  end
end
