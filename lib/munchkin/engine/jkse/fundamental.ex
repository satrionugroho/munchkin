defmodule Munchkin.Engine.Jkse.Fundamental do
  use Munchkin.Engine.Jkse.Engine

  alias Munchkin.Engine.Jkse.Fundamental.Type

  def get(ticker, opts \\ []) do
    Keyword.get(opts, :period)
    |> case do
      nil -> raise ArgumentError, "please specify the fundamental data period"
      y -> valid_period(y)
    end
    |> do_get_fundamental_data(ticker)
    |> parse_fundamental_data()
    |> then(fn
      {:error, _msg} = ret ->
        ret

      data when is_map(data) ->
        data
        |> Map.put("period", Keyword.get(opts, :period))
        |> Map.put("ticker", ticker)
        |> then(fn d -> {:ok, d} end)
    end)
  end

  defp valid_period(<<rawyear::binary-size(4)>> <> period) do
    year = Munchkin.Engine.Jkse.Utils.safe_parse_integer(rawyear, 0)

    if year == 0 do
      raise ArgumentError, "please enter valid year"
    end

    {year, translate_fundamental_period(period)}
  end

  defp valid_period(err) do
    raise ArgumentError, "Cannot parse period with value #{inspect(err)}"
  end

  defp translate_fundamental_period(key) do
    Map.get(fundamental_period_dict(), String.downcase(key))
    |> case do
      nil -> raise ArgumentError, "please enter valid period"
      data -> data
    end
  end

  defp fundamental_period_dict do
    %{
      "tw1" => "tw1",
      "tw2" => "tw2",
      "tw3" => "tw3",
      "q1" => "tw1",
      "q2" => "tw2",
      "q3" => "tw3",
      "q4" => "audit",
      "audit" => "audit",
      "fy" => "audit"
    }
  end

  defp do_get_fundamental_data({year, period}, ticker) do
    path =
      get_url(:financial_data, %{
        "periode" => period,
        "year" => year,
        "kodeEmiten" => ticker
      })

    fetch(path, timeout: :timer.seconds(45))
    |> case do
      {:ok, %{"Results" => [data | _last]}} ->
        Map.get(data, "Attachments", [])
        |> Enum.find(fn a ->
          Map.get(a, "File_Type", "")
          |> String.equivalent?(".xlsx")
        end)
        |> download_fundamental_data()

      err ->
        :logger.error("Cannot get fundamental data with error #{inspect(err)}")
        {:error, "cannot get fundamental data"}
    end
  end

  defp download_fundamental_data(%{"Emiten_Code" => code, "File_Path" => path}) do
    url = Path.join(base_url(), path)

    case download(code, url, timeout: :timer.minutes(1)) do
      {:ok, %{"file" => file}} -> {:ok, file}
      err -> err
    end
  end

  defp download_fundamental_data(err) do
    raise ArgumentError, "Cannot download fundamental data with error #{inspect(err)}"
  end

  defp parse_fundamental_data({:ok, file}) do
    File.exists?(file)
    |> case do
      true -> do_parse_fundamental_data(file)
      _ -> raise ArgumentError, "Cannot find given file"
    end
    |> tap(fn _ ->
      File.rm(file)
    end)
  end

  defp parse_fundamental_data({:error, _msg} = ret), do: ret

  defp parse_fundamental_data(err) do
    raise ArgumentError, "Cannot parse fundamental data due to error #{inspect(err)}"
  end

  defp do_parse_fundamental_data(file) do
    with references <- Xlsxir.multi_extract(file),
         general <- parse_general_data(references),
         balance_sheet <- parse_balance_sheet(references, general),
         income_statement <- parse_income_statement(references, general),
         cashflow <- parse_cashflow(references, general) do
      %{
        "balance_sheet" => Task.await(balance_sheet),
        "income_statement" => Task.await(income_statement),
        "cashflow" => Task.await(cashflow),
        "general" => general
      }
    end
  end

  defp parse_general_data(references) do
    find_correct_ref(Type.general_information(), references)
    |> parse_data("general_information", nil)
  end

  defp parse_balance_sheet(references, general) do
    Task.async(fn ->
      find_correct_ref(Type.balance_sheets(), references)
      |> parse_data("balance_sheet", general)
    end)
  end

  defp parse_income_statement(references, general) do
    Task.async(fn ->
      find_correct_ref(Type.income_statements(), references)
      |> parse_data("income_statement", general)
    end)
  end

  defp parse_cashflow(references, general) do
    Task.async(fn ->
      find_correct_ref(Type.cashflows(), references)
      |> parse_data("cashflow", general)
    end)
  end

  defp find_correct_ref(types, references) do
    Enum.find(references, fn
      {:ok, ref} ->
        name = Xlsxir.get_info(ref, :name)
        Enum.member?(types, name)
    end)
    |> then(fn
      {:ok, ref} -> ref
      _ -> nil
    end)
  end

  defp parse_data(nil, _name, _general_data), do: %{}

  defp parse_data(ref, "general_information", general_data) do
    with raw_keys <- Xlsxir.get_col(ref, "C"),
         val <- Xlsxir.get_col(ref, "B"),
         true <- validate_against_key(val, raw_keys),
         type <- Xlsxir.get_info(ref, :name),
         keys <- ["Test" | raw_keys] do
      translate_data(keys, val, {"general_information", type}, general_data)
    end
  end

  defp parse_data(ref, _name, general_data) do
    with raw_keys <- Xlsxir.get_col(ref, "D"),
         cy_value <- Xlsxir.get_col(ref, "B"),
         true <- validate_against_key(cy_value, raw_keys),
         type <- Xlsxir.get_info(ref, :name),
         keys <- ["Test" | raw_keys] do
      translate_data(keys, cy_value, type, general_data)
    end
  end

  def validate_against_key(val, keys) when length(val) > length(keys), do: true
  def validate_against_key(_, _), do: false

  defp translate_data(keys, value, {"general_information", type}, _void) do
    translations = Munchkin.Engine.Jkse.Fundamental.Translation.get(type)

    Enum.zip(keys, value)
    |> Enum.map(&rename_key(translations, &1))
    |> Enum.reject(fn {key, _} -> is_nil(key) end)
    |> Enum.into(%{})
    |> Map.put("type", type)
  end

  defp translate_data(keys, value, name, general) do
    translations = Munchkin.Engine.Jkse.Fundamental.Translation.get(name)
    rounding = Map.get(general, "rounding") |> translate_to_numeric()

    base = %{
      "conversion_rate" => Map.get(general, "conversion_rate"),
      "version" => name,
      "filling_date" => get_filling_date(general),
      "ccy" => get_currency(general),
      "rounding" => rounding
    }

    Enum.zip(keys, value)
    |> Enum.map(&rename_key(translations, &1))
    |> Enum.reject(fn {key, _} -> is_nil(key) end)
    |> Enum.into(%{})
    |> calculate_formulas(translations, 1)
    |> Map.merge(base)
  end

  defp rename_key(translations, {key, value}) when not is_nil(key) do
    with {new_key, _mapped} <- find_key(translations, String.downcase(key)) do
      {new_key, value}
    else
      _ -> rename_key(nil, nil)
    end
  end

  defp rename_key(_translations, _), do: {nil, 0}

  defp find_key(translations, key) do
    Enum.find(translations, fn
      {_k, %{"value" => v}} ->
        String.downcase(v)
        |> String.equivalent?(key)

      {_k, v} ->
        v == key
    end)
  end

  defp calculate_formulas(data, translations, base) do
    Enum.reduce(translations, data, fn {key, value}, acc ->
      do_calculations({key, value}, acc, translations, base)
    end)
  end

  defp do_calculations({key, %{"formula" => [], "multiplier" => mul}}, acc, _translations, base) do
    case get_current_value(acc, key, mul) do
      num when is_number(num) -> Map.put(acc, key, num * base)
      val -> Map.put(acc, key, val)
    end
  end

  defp do_calculations(
         {key, %{"formula" => formulas, "multiplier" => mul}},
         acc,
         translations,
         base
       ) do
    case get_current_value(acc, key, mul) do
      nil -> generate_new_value(acc, formulas, translations)
      num -> num
    end
    |> then(fn
      num when is_number(num) -> Map.put(acc, key, num * base)
      val -> Map.put(acc, key, val)
    end)
  end

  defp generate_new_value(acc, formulas, translations) do
    formulas
    |> breakdown!(translations)
    |> Enum.reduce(0, fn {key, mul}, res ->
      get_current_value(acc, key, mul, 0)
      |> Kernel.+(res)
    end)
  end

  defp get_current_value(data, key, mul, default \\ nil) do
    case Map.get(data, key) do
      nil -> default
      num -> Kernel.*(num, mul)
    end
  end

  defp breakdown!(formulas, translations) do
    Map.take(translations, formulas)
    |> Enum.map(fn
      {key, %{"formula" => [], "multiplier" => mul}} -> {key, mul}
      {_key, %{"formula" => fs}} -> breakdown!(fs, translations)
    end)
    |> List.flatten()
  end

  defp translate_to_numeric(data) do
    key = String.downcase(data)

    %{
      "amount" => 1,
      "thousand" => 1_000,
      "million" => 1_000_000,
      "billion" => 1_000_000_000
    }
    |> Enum.reduce(nil, fn {k, val}, acc ->
      case String.contains?(key, k) do
        true -> val
        _ -> acc
      end
    end)
  end

  defp get_currency(data) do
    Map.get(data, "currency", "")
    |> String.split("/")
    |> List.last()
    |> String.trim()
    |> case do
      "" -> "idr"
      data -> String.downcase(data)
    end
  end

  defp get_filling_date(data) do
    ~w(date_of_audit filling_date current_start_date)
    |> Enum.reduce(nil, fn
      _key, acc when not is_nil(acc) -> acc
      key, _acc -> Map.get(data, key)
    end)
  end
end
