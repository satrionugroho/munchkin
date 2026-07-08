defmodule CompanyMigrator do
  def get_company_data(ticker) do
    Munchkin.Repo.transact(fn ->
      get_company_info(ticker)
      get_company_eod(ticker)
    end)

    get_company_statements(ticker)

    :timer.sleep(500)
  end

  defp get_company_info(ticker) do
    Munchkin.Engine.Jkse.Company.profile(ticker)
    |> Map.put("exchange", "JK")
    |> Map.put("ticker", ticker)
    |> Map.put("type_id", 1)
    |> Munchkin.Inventory.create_asset()
  end

  defp get_company_eod(ticker) do
    Munchkin.Engine.Jkse.Stock.company(ticker)
    |> then(&Munchkin.Inventory.add_trade_data(%{"ticker" => ticker, "trades" => &1}))
  end

  defp get_company_statements(ticker) do
    year = Date.utc_today().year
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
              "cannot download fundamental data with ticker #{ticker} for #{period}"
            )
        end)
      end)
    end)
  end

  def migrate() do
    # tickers = ["BBCA", "BBNI", "INKP", "GOTO", "BMRI", "BJTM", "ACES"]
    tickers = ["INKP", "ACES", "BMRI", "BJTM"]

    Enum.map(tickers, &get_company_data/1)
  end
end

CompanyMigrator.migrate()
