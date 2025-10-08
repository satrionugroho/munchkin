defmodule Munchkin.Engine.Jkse.Config do
  @config Application.compile_env(:munchkin, Munchkin.Engine.Jkse, [])

  def base_url, do: config() |> Keyword.get(:base_url, "https://www.idx.co.id")
  def request_timeout, do: config() |> Keyword.get(:request_timeout, 50_000)
  def receive_timeout, do: config() |> Keyword.get(:receive_timeout, 50_000)

  def get_url(category, params \\ %{}) do
    URI.new!(base_url())
    |> Map.put(:path, path_decider(category))
    |> Map.put(:query, query_decider(category, params))
    |> URI.to_string()
  end

  def user_agents do
    default = [
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/31.0.1636.0 Safari/537.36",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:23.0) Gecko/20100101 Firefox/23.0",
      "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36",
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:134.0) Gecko/20100101 Firefox/134.0",
      "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/78.0.3904.108 Chrome/78.0.3904.108 Safari/537.36"
    ]

    config()
    |> Keyword.get(:user_agents, default)
  end

  def app_id, do: Keyword.get(@config, :database_id)
  def user_agent, do: Enum.random(user_agents())
  def driver, do: config() |> Keyword.get(:driver, driver_chrome())
  def driver_chrome, do: :chrome
  def driver_webkit, do: :webkit

  def runtime_dir do
    :code.priv_dir(:munchkin)
    |> to_string()
    |> Path.join("/runtime/node")
  end

  def json_module, do: config() |> Keyword.get(:json_module, Jason)
  def config, do: @config

  defp path_decider(category), do: Map.get(url_list(), category)

  defp query_decider(category, options) do
    Map.get(params(), category)
    |> Enum.reduce(%{}, fn
      [key, "drop"], acc ->
        case Map.get(options, key) do
          nil -> acc
          d -> Map.put(acc, key, d)
        end

      [key, default], acc ->
        value = Map.get(options, key, default)
        Map.put(acc, key, value)

      key, acc ->
        case Map.get(options, key) do
          nil -> acc
          val -> Map.put(acc, key, val)
        end
    end)
    |> URI.encode_query()
  end

  defp url_list do
    %{
      stock_summary: "/primary/TradingSummary/GetStockSummary",
      company_profile: "/primary/ListedCompany/GetCompanyProfilesDetail",
      corporate_action: "/primary/ListingActivity/GetIssuedHistory",
      company_announcement: "/primary/ListedCompany/GetProfileAnnouncement",
      ticker_trading_info: "/primary/ListedCompany/GetTradingInfoSS",
      financial_data: "/primary/ListedCompany/GetFinancialReport",
      index_summary: "/primary/TradingSummary/GetIndexSummary",
      stock_list: "/primary/Helper/GetEmiten",
      company_esg: "/secondary/get/esg",
      stock_suspension: "/primary/page/en/listed-companies/suspension-6-months"
    }
  end

  defp params do
    %{
      stock_summary: [["date", "drop"], ["start", 0], ["length", 9999]],
      company_profile: ["KodeEmiten", ["language", "en-us"]],
      corporate_action: [
        ["kodeEmiten", "drop"],
        ["start", 0],
        ["length", 9999],
        ["dateFrom", ""],
        ["dateTo", ""]
      ],
      company_announcement: [
        "KodeEmiten",
        ["indexFrom", 0],
        ["pageSize", 10],
        "dateFrom",
        "dateTo",
        ["lang", "en"],
        ["keyword", ""]
      ],
      ticker_trading_info: ["code", ["start", 0], ["length", 1000]],
      financial_data: [
        "periode",
        "year",
        "kodeEmiten",
        ["indexFrom", 0],
        ["pageSize", 1000],
        ["reportType", "rdf"]
      ],
      index_summary: [["date", "drop"], ["length", 9999], ["start", 0]],
      stock_list: [],
      company_esg: [["pageSize", 10000]],
      stock_suspension: []
    }
  end
end
