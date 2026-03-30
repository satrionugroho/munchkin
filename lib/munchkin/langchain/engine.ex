defmodule Munchkin.Langchain.Engine do
  use GenServer

  @available_engine [
    %{label: :google, order: 1},
    %{label: :deepseek, order: 2},
    %{label: :openai, order: 3}
  ]

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def init(_), do: {:ok, 0}

  def create(opts \\ []), do: GenServer.call(__MODULE__, {:run, opts})

  def user_message(params) do
    user_params(params)
    |> Enum.join("\n")
    |> String.trim_leading()
    |> LangChain.Message.new_user!()
  end

  def handle_call({:run, opts}, _from, state) do
    case Keyword.get(opts, :engine) do
      e when e in [:google, :deepseek, :openai] ->
        do_create(e, opts)
        |> then(fn e -> {:reply, e, state} end)

      _ ->
        create_engine(state, opts)
        |> then(fn e -> {:reply, e, state + 1} end)
    end
  end

  defp create_engine(state, opts) do
    index = rem(state, length(@available_engine))

    Enum.at(@available_engine, index)
    |> Map.get(:label)
    |> do_create(opts)
  end

  defp do_create(:google, opts) do
    model = Keyword.get(opts, :model, "gemini-2.5-flash-lite")

    LangChain.ChatModels.ChatGoogleAI.new!(%{
      temperature: 0,
      stream: false,
      model: model,
      api_key: System.get_env("GEMINI_API_KEY", "")
    })
  end

  defp do_create(:deepseek, opts) do
    model = Keyword.get(opts, :model, "deepseek-chat")

    LangChain.ChatModels.ChatDeepSeek.new!(%{
      temperature: 0,
      stream: false,
      model: model,
      api_key: System.get_env("DEEPSEEK_API_KEY", "")
    })
  end

  defp do_create(:openai, opts) do
    model = Keyword.get(opts, :model, "gpt-5-nano")

    LangChain.ChatModels.ChatOpenAI.new!(%{
      temperature: 0,
      stream: false,
      model: model,
      api_key: System.get_env("OPENAI_API_KEY", "")
    })
  end

  defp user_params(params) do
    Enum.sort_by(params, &sorter/1)
    |> Enum.map(fn
      {"analizer", v} -> compose_analizer(v)
      {"spec", v} -> user_spec(v)
      {"company", v} -> company_spec(v)
      _ -> ""
    end)
  end

  defp sorter({"spec", _v}), do: 1
  defp sorter({"company", _v}), do: 2
  defp sorter({_, _v}), do: 3

  defp company_spec(spec) do
    a = "The company details are:"
    items = ["current_price", "sector", "subsector", "industry", "subindustry"]

    Enum.reduce(items, a, fn t, acc ->
      case Map.get(spec, t) do
        nil -> acc
        s -> Kernel.<>(acc, "\n- The #{String.replace(t, "_", " ")} is #{s}")
      end
    end)
    |> Kernel.<>("\n")
  end

  defp user_spec(spec) do
    projections = Map.get(spec, "projections", 1) |> get_projections()
    risk_adjusted = Map.get(spec, "risk") |> user_risk()
    risk_tolerance = Map.get(spec, "risk") |> user_tolerance()
    mos = Map.get(spec, "risk") |> margin_of_safety_calculation()
    margin_of_safety = Map.get(spec, "risk") |> user_margin_of_safety(mos)

    ~s"""
    I want to evaluate a company, my preference are
    1. I want to invest at least for #{projections}
    2. #{risk_adjusted}
    3. #{risk_tolerance}
    4. #{margin_of_safety}
    """
  end

  defp get_projections(number) do
    case number do
      "1" -> "less than 1 month"
      "2" -> "around 2 to 3 months"
      "3" -> "around 4 until 6 months"
      "4" -> "more than 6 months but not over 1 year"
      "5" -> "about 1 to less than 2 years"
      "6" -> "more than 2 years"
    end
  end

  defp user_risk(risk) do
    case risk do
      "conservative" ->
        "I MUST gain the capital preservation and income generation."

      "moderate" ->
        "I MUST balance between steady growth and income, with a willingness to accept some volatility."

      "agressive" ->
        "I MUST maximizing the capital appreciation (wealth growth) over the long term."

      "speculative" ->
        "I WANT to get extremely high, rapid returns and ignore some risk"
    end
  end

  defp user_tolerance(risk) do
    case risk do
      "conservative" ->
        "I prefer a stable, low-risk investsments and unconfortable with the market fluctuations."

      "moderate" ->
        "I can tolerate moderate market fluctuations in exchange on better returns."

      "agressive" ->
        "I prepared to accept a significant volatility and potential short-term losses in my portfolio."

      "speculative" ->
        "I confortable to risking a significant portion or even all of their principal"
    end
  end

  defp user_margin_of_safety(risk, mos) do
    case risk do
      "conservative" ->
        "I MUST follow the margin of safety around #{mos}%"

      "moderate" ->
        "I can follow the margin of safety around #{mos}% if applicable but not below from #{mos - 5}%"

      "agressive" ->
        "I could follow the margin of safety less #{mos}% but is not mandatory as long as the returns are high"

      "speculative" ->
        "I am not follow the margin of safety."
    end
  end

  defp margin_of_safety_calculation(risk) do
    case risk do
      "conservative" -> 15
      "moderate" -> 10
      "agressive" -> 5
      "speculative" -> 0
    end
  end

  defp compose_analizer(%{"analizers" => analizers}) do
    Enum.map(analizers, &analizer_type/1)
  end

  defp compose_analizer(_), do: ""

  defp analizer_type({"quality", qualities}) do
    init = "The quality models in last 5 years (first index are the recent) are:"

    Enum.reduce(qualities, [init], fn {key, value}, acc ->
      val =
        :lists.reverse(value)
        |> Enum.reject(&is_nil/1)
        |> Enum.join(",")

      ["- #{model_name(key)} are #{val}" | acc]
    end)
    |> :lists.reverse()
    |> Enum.join("\n")
    |> Kernel.<>("\n\n")
  end

  defp analizer_type({"valuation", valuations}) do
    init = "The fundamental valuation models results are:"

    Enum.reduce(valuations, [init], fn
      {k, val}, acc when is_map(val) ->
        temp =
          Enum.reduce(val, [], fn {t, v}, a ->
            ["- #{String.upcase(k)} (#{String.capitalize(t)}) is #{v}" | a]
          end)
          |> Enum.join("\n")

        [temp | acc]

      {k, v}, acc ->
        ["- #{String.upcase(k)} is #{v}" | acc]
    end)
    |> :lists.reverse()
    |> Enum.join("\n")
    |> Kernel.<>("\n\n")
  end

  defp analizer_type({"relative", qualities}) do
    init = "The relative models calculation shows:"

    Enum.reduce(qualities, [init], fn {key, values}, acc ->
      data =
        Enum.reduce(values, [], fn
          {k, v}, a when v !== 0 ->
            ["#{String.upcase(k)} = #{v}" | a]

          _, a ->
            a
        end)
        |> :lists.reverse()
        |> Enum.join(",")

      ["- #{model_name(key)} calculation at #{data}" | acc]
    end)
    |> :lists.reverse()
    |> Enum.join("\n")
    |> Kernel.<>("\n\n")
  end

  defp analizer_type({_, _qualities}), do: ""

  defp model_name(name) do
    case name do
      "evebit" -> "EV/EBIT"
      "evebitda" -> "EV/EBITDA"
      "evsales" -> "EV/Sales"
      "fcfyield" -> "FCF Yield"
      "pricetofcf" -> "P/FCF"
      "pricetobook" -> "P/B"
      "pricetoearn" -> "P/E"
      "earningyield" -> "Earning Yield"
      "dividendyield" -> "Dividend Yield"
      "3c" -> "Cash Conversion Cycle"
      "piotroksy" -> "Piotroksi F-Score"
      "beneish" -> "Beneish M-Score"
      "altman" -> "Altman Z-Score"
      "dupont" -> "Dupont Analysis"
      "unholy" -> "Unholy Trinity Analysis"
      "montier" -> "Montier C-Score"
      "modc" -> "Modified C-Score"
      "bs_accruals" -> "Balance Sheet Accruals"
      "cf_accruals" -> "Cashflow Accruals"
      "sloan" -> "Sloan Ratio"
      "tlta" -> "Total Liabilities / Total Assets"
      "magic_formula" -> "Earning Yield"
      "magic_formula_1" -> "Return on Capital"
      "shareyield" -> "Shareholder's Yield"
      _ -> name
    end
  end
end
