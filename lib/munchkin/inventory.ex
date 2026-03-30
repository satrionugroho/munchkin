defmodule Munchkin.Inventory do
  alias Munchkin.Inventory.Analize
  alias Munchkin.Repo
  alias Munchkin.Inventory.Fundamental
  alias Munchkin.Inventory.Fundamental.Gate

  alias Munchkin.Inventory.{
    Asset,
    AssetTicker,
    AssetSource,
    Summary,
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

  def create_asset(attrs) do
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
    |> Repo.transact()
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

  def get_last_trade_history(ticker_or_id, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    type_id = Keyword.get(opts, :type)

    try do
      id = String.to_integer(ticker_or_id)
      query = from t in TradeHistory, where: t.asset_id == ^id, limit: 1, order_by: {:desc, :date}
      repo.one(query)
    rescue
      ArgumentError ->
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
        |> then(fn res ->
          case period do
            [_ | _] -> res
            _ -> List.first(res)
          end
        end)

      data ->
        IO.inspect(data)

        {:error,
         "fundamental data with with ticker #{inspect(ticker)} and period of #{inspect(period)} is not found"}
    end
  end

  def fundamental_data_standardization(%Fundamental{} = data) do
    do_get_fundamental_detail(data, [])
    |> List.first()
  end

  def fundamental_data_standardization(_), do: {:error, "please parse from fundamental schema"}

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
      IO.inspect(fcf)

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
        IO.inspect(err)
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
end
