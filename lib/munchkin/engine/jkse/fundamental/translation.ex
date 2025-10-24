defmodule Munchkin.Engine.Jkse.Fundamental.Translation do
  use GenServer

  alias Munchkin.Engine.Jkse.Fundamental.Type
  alias NimbleCSV.RFC4180, as: CSV

  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  @impl true
  def init(_args) do
    table = :ets.new(:fundamental_translations, [:set, :protected])
    Process.send_after(self(), :load_data, 500)

    {:ok, table}
  end

  defp parse_from_ext(name, ext \\ "csv") do
    with file <- get_relative(name, ext),
         true <- File.exists?(file),
         data <- load_data_ext_based(file, ext) do
      {name, data}
    else
      false ->
        :logger.warning("cannot load file")
        nil
    end
  end

  defp get_relative(path, ext) do
    :code.priv_dir(:munchkin)
    |> Kernel.to_string()
    |> Path.join("/data/#{path}.#{ext}")
  end

  defp load_data_ext_based(file, "csv") do
    file
    |> File.read!()
    |> CSV.parse_string()
    |> Enum.reduce(%{}, fn
      [key, value, formula, ""], acc ->
        Map.put(acc, key, %{
          "value" => value,
          "formula" => get_formula(formula),
          "multiplier" => 1
        })

      [key, value, formula, multiplier], acc ->
        Map.put(acc, key, %{
          "value" => value,
          "formula" => get_formula(formula),
          "multiplier" => String.to_integer(multiplier)
        })

      [key, value], acc ->
        Map.put(acc, key, %{"value" => value})

      _, acc ->
        acc
    end)
  end

  defp load_data_ext_based(file, "json") do
    file
    |> File.read!()
    |> then(fn d ->
      apply(Phoenix.json_library(), :decode, [d, []])
    end)
    |> case do
      {:ok, data} ->
        data

      _ ->
        :logger.error("cannot parse json data on file #{inspect(file)}")
        ""
    end
  end

  defp load_data_ext_based(file, ext) do
    :logger.warning("cannot parse #{inspect(file)} with ext #{inspect(ext)}")
    :ok
  end

  def get(key) do
    case GenServer.call(__MODULE__, {:get, key}) do
      {:ok, data} ->
        data

      _ ->
        :logger.warning("cannot get #{key} translation")
        %{}
    end
  end

  def parse(data) do
    case Map.get(data, "version") do
      nil -> {:error, "cannot parse the given data"}
      ver -> parse_detail(ver, data)
    end
  end

  defp parse_detail(version, data) do
    fundamental_type = Type.t(version)

    case GenServer.call(__MODULE__, {:parse, version, fundamental_type}) do
      {:ok, translations} ->
        parse_data(data, version, translations)

      _ ->
        :logger.warning("cannot parse fundamental with type #{inspect(version)}")
        {:ok, %{}}
    end
  end

  defp parse_data(data, version, translations) do
    Enum.reduce(translations, %{}, fn {key, translation}, acc ->
      Map.put(acc, key, get_data(data, version, translation))
    end)
    |> calculate_calculated_items()
  end

  defp get_data(data, version, translations) when is_list(translations) do
    Enum.reduce(translations, [], fn key, acc ->
      case get_data(data, version, key) do
        0 -> acc
        nil -> acc
        d -> [d | acc]
      end
    end)
    |> then(fn res ->
      case Enum.all?(res, &is_number/1) do
        true -> Enum.sum(res)
        _ -> res
      end
    end)
  end

  defp get_data(_data, version, "CALCULATED" <> rest = key) do
    case String.contains?(rest, version) do
      true -> key
      _ -> 0
    end
  end

  defp get_data(data, version, translation) do
    case Regex.match?(~r/\d/, translation) do
      true -> get_data_advanced(data, version, translation)
      _ -> Map.get(data, translation, 0)
    end
  end

  defp get_data_advanced(data, version, translation) do
    case String.contains?(translation, version) do
      true ->
        key = String.replace(translation, ~r/\d|\W/, "")
        Map.get(data, key, 0)

      _ ->
        0
    end
  end

  defp calculate_calculated_items(data) do
    Enum.reduce(data, %{}, fn
      {key, val}, acc when is_number(val) ->
        Map.put(acc, key, val)

      {key, val}, acc when is_bitstring(val) ->
        value = calculated_value(data, val)
        Map.put(acc, key, value)

      {key, val}, acc when is_list(val) ->
        value = Enum.map(val, &calculated_value(data, &1)) |> Enum.sum()
        Map.put(acc, key, value)
    end)
  end

  defp calculated_value(data, "CALCULATED{" <> rest) do
    String.split(rest, "}")
    |> List.first()
    |> String.split(",")
    |> Enum.reduce(0, fn key, acc ->
      mul =
        case String.contains?(key, "-") do
          true -> -1
          _ -> 1
        end

      case Map.get(data, key, 0) do
        nil -> acc
        val when is_number(val) -> acc + val * mul
        val when is_bitstring(val) -> acc + calculated_value(data, val)
      end
    end)
  end

  defp calculated_value(data, _key) do
    data
  end

  def reload!, do: GenServer.cast(__MODULE__, :reload)

  defp get_formula(""), do: []
  defp get_formula(f), do: String.split(f, ",")

  @impl true
  def handle_call({:get, key}, _from, table) do
    case lookup_value(table, key) do
      {:ok, _data} = result ->
        {:reply, result, table}

      err ->
        :logger.warning("cannot lookup data with key=#{inspect(key)}")
        {:reply, err, table}
    end
  end

  @impl true
  def handle_call({:parse, key, name}, _from, table) do
    with {:ok, _category} = result <- lookup_value(table, object_data(name)) do
      {:reply, result, table}
    else
      err ->
        :logger.warning("cannot parse data from key=#{inspect(key)}")
        {:reply, err, table}
    end
  end

  @impl true
  def handle_info(:load_data, table) do
    _ = translation_dictionary(table)
    _ = translation_meaning(table)

    :logger.info("translation data is sucessfully loaded")

    {:noreply, table}
  end

  @impl true
  def handle_cast(:reload, table) do
    :logger.info("try to reload the translation table.")
    :ets.delete_all_objects(table)
    Process.send_after(self(), :load_data, 100)

    {:noreply, table}
  end

  defp translation_dictionary(table) do
    Munchkin.Engine.Jkse.Fundamental.Type.available_types()
    |> Enum.map(&parse_from_ext(&1))
    |> Enum.reject(&Kernel.is_nil/1)
    |> Enum.map(fn {key, value} ->
      :ets.insert_new(table, {key, value})
    end)
  end

  defp translation_meaning(table) do
    ~w(balance_sheet cashflow income_statement)
    |> Enum.map(&parse_from_ext(&1, "json"))
    |> Enum.reject(&Kernel.is_nil/1)
    |> Enum.map(fn {key, value} ->
      :ets.insert_new(table, {object_data(key), value})
    end)
  end

  defp lookup_value(table, key) do
    case :ets.lookup(table, key) do
      [{^key, data}] -> {:ok, data}
      _ -> {:error, "not found"}
    end
  end

  defp object_data(key), do: "idx_#{key}"
end
