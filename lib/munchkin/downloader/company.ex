defmodule Munchkin.Downloader.Company do
  def download_profile do
    Munchkin.Engine.Jkse.Stock.list()
    |> case do
      {:ok, data} -> Enum.map(data, &Map.take(&1, ["ticker"]))
      _ -> []
    end
    |> download_profile()
  end

  defp download_profile(data) do
    Enum.map(data, fn d ->
      Munchkin.Downloader.download({__MODULE__, :individual_company_profile, [d]})
    end)
  end

  def individual_company_profile(ticker) do
    case Munchkin.Inventory.get_asset(ticker) do
      %Munchkin.Inventory.Asset{} = asset ->
        {:ok, asset}

      _ ->
        Munchkin.Engine.Jkse.Company.profile(ticker)
        |> Map.put("ticker", ticker)
        |> Map.put("type_id", "stock")
        |> Map.put("exchange", "JK")
        |> Map.put("source", Munchkin.Engine.Jkse.Instance.get())
        |> Munchkin.Inventory.create_asset()
    end
  end

  def individual_fundamental_data(ticker, given_year \\ nil) do
    year = given_year || Date.utc_today().year
    lft = year - 5

    Munchkin.Inventory.fundamental_periods()
    |> Enum.map(fn p ->
      Range.new(lft, year)
      |> Enum.map(fn y ->
        period = String.upcase("#{y}#{p}")

        Munchkin.Engine.Jkse.Fundamental.get(ticker, period: period)
        |> then(fn
          {:ok, data} ->
            Munchkin.Inventory.insert_fundamentals(data)

          _ ->
            :logger.warning(
              "cannot download fundamental data with ticker #{ticker} for period #{period}"
            )
        end)
      end)
    end)
  end

  def individual_trade_history(ticker, opts \\ []) do
    Munchkin.Engine.Jkse.Stock.company(ticker)
    |> case do
      [_ | _] = data ->
        Munchkin.Inventory.add_trade_data(%{
          "ticker" => ticker,
          "asset" => Keyword.get(opts, :asset),
          "trades" => data
        })
    end
  end

  def import_idx_data(opts \\ []) do
    case Keyword.get(opts, :async) do
      true -> import_idx_data_async(opts)
      _ -> import_idx_data_sync(opts)
    end
  end

  defp import_idx_data_async(opts) do
    Munchkin.Downloader.download(fn ->
      import_idx_data_sync(Keyword.drop(opts, [:async]))
      :ok
    end)
  end

  defp import_idx_data_sync(opts) do
    Munchkin.Engine.Jkse.Stock.list()
    |> case do
      {:ok, data} -> import_companies_data(data, opts)
      _ -> []
    end
  end

  def import_single_idx_ticker(ticker, opts \\ []), do: download_company_data(ticker, opts)

  defp import_companies_data(data, opts) do
    case Keyword.get(opts, :async) do
      true ->
        Enum.map(
          data,
          &Munchkin.Downloader.download({__MODULE__, :download_company_data, [&1, opts]})
        )

      _ ->
        Enum.with_index(data, fn
          %{"ticker" => ticker}, index ->
            case Keyword.get(opts, :skip) do
              num when num > index and is_number(num) ->
                :logger.info("Skip for ticker #{ticker}")
                :ok

              _ ->
                download_company_data(ticker, opts)
                :timer.sleep(1)
            end

          _, _ ->
            :error
        end)
    end
  end

  defp download_company_data(ticker, opts) do
    individual_company_profile(ticker)
    |> tap(fn _ -> :logger.info("success fetching company profile with ticker #{ticker}") end)
    |> then(fn
      {:ok, %Munchkin.Inventory.Asset{} = asset} ->
        should_download_fundamental(asset, ticker, opts)

      {:ok, %{asset: asset}} ->
        :logger.info(
          "Asset was inserted. Continue to process trade history with ticker #{ticker}"
        )

        should_download_fundamental(asset, ticker, opts)

      err ->
        err
    end)
  end

  defp should_download_fundamental(asset, ticker, opts) do
    case Keyword.get(opts, :fundamental) do
      true ->
        individual_fundamental_data(ticker)
        |> then(fn
          {:ok, _fundamentals} -> individual_fundamental_data(ticker)
          _ -> should_download_history(asset, ticker, opts)
        end)

      _ ->
        should_download_history(asset, ticker, opts)
    end
  end

  defp should_download_history(asset, ticker, opts) do
    case Keyword.get(opts, :history) do
      true -> individual_trade_history(ticker, Keyword.put_new(opts, :asset, asset))
      _ -> {:ok, asset}
    end
  end

  def since(date, opts \\ [])

  def since(date, opts) when is_bitstring(date) do
    case Date.from_iso8601(date) do
      {:ok, d} -> since(d, opts)
      _ -> since(nil)
    end
  end

  def since(%Date{} = date, opts) do
    today = Date.utc_today()

    case Date.diff(today, date) do
      0 -> process_today(opts)
      d when d > 0 -> process_download_trade(date, opts)
      _ -> {:error, "date must be before this day"}
    end
  end

  def since(_, _), do: {:error, "please input a valid date"}

  def today(opts \\ []), do: process_today(opts)

  defp process_today(opts) do
    dt =
      DateTime.utc_now()
      |> DateTime.shift_zone!("Asia/Jakarta", Tzdata.TimeZoneDatabase)

    dt
    |> DateTime.to_time()
    |> Time.after?(~T[17:05:00])
    |> case do
      true ->
        :logger.info("downloading today stocks market data")
        process_download_trade(DateTime.to_date(dt), opts)

      _ ->
        {:error, "market not closed yet"}
    end
  end

  defp process_download_trade(date, opts) do
    case Keyword.get(opts, :async) do
      true -> download_stock_trade_async(date)
      _ -> do_download_daily_stock_trade(date)
    end
  end

  defp download_daily_data(date) do
    case Date.day_of_week(date) do
      d when d > 5 ->
        :logger.info("market not open")
        {:error, "market not open on weekend"}

      _ ->
        :logger.info("trying to download market data on #{date}")

        Munchkin.Engine.Jkse.Stock.daily(date)
        |> parse_stock_data()
    end
  end

  defp do_download_daily_stock_trade(date) do
    today = Date.utc_today()

    Date.range(date, today)
    |> Enum.map(fn curr ->
      download_daily_data(curr)
    end)
  end

  defp download_stock_trade_async(date) do
    Munchkin.Downloader.download(fn ->
      do_download_daily_stock_trade(date)
      :ok
    end)
  end

  defp parse_stock_data(%{"data" => data, "date" => date}),
    do: Munchkin.Inventory.insert_daily_asset_data(data, date)
end
