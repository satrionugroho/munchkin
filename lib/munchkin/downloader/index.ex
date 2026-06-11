defmodule Munchkin.Downloader.Index do
  def since(date, opts \\ [])

  def since(date, opts) when is_bitstring(date) do
    case Date.from_iso8601(date) do
      {:ok, d} -> since(d, opts)
      _ -> {:error, "please input a valid date"}
    end
  end

  def since(%Date{} = date, opts) do
    today = Date.utc_today()

    case Date.before?(date, today) do
      true -> process_download(date, opts)
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
        :logger.info("downloading today index market data")
        process_daily(DateTime.to_date(dt), opts)

      _ ->
        {:error, "market not closed yet"}
    end
  end

  defp process_individual_date(date, opts) do
    today = Date.utc_today()

    case Date.diff(today, date) do
      0 -> process_today(opts)
      d when d > 0 -> process_daily(date, opts)
      _ -> {:error, "date must be before this day"}
    end
  end

  defp process_daily(date, _opts) do
    case Date.day_of_week(date) do
      d when d > 5 ->
        :logger.info("market not open")
        {:error, "market not open on weekend"}

      _ ->
        :logger.info("currently downloading index data on date #{date}")

        Munchkin.Engine.Jkse.Index.daily(date)
        |> parse_index_data()
    end
  end

  defp process_download(date, opts) do
    case Keyword.get(opts, :async) do
      true -> async_download(date)
      _ -> do_download(date, opts)
    end
  end

  defp do_download(date, opts) do
    today = Date.utc_today()

    Date.range(date, today)
    |> Enum.map(fn current ->
      process_individual_date(current, opts)
    end)
  end

  defp async_download(date) do
    Munchkin.Downloader.download(fn ->
      do_download(date, [])
    end)
  end

  defp parse_index_data(%{"data" => data, "date" => date}),
    do: Munchkin.Inventory.insert_daily_asset_data(data, date, type: "index")

  defp parse_index_data(_) do
    :logger.warning("cannot download index data")
    {:ok, []}
  end
end
