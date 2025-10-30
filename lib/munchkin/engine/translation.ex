defmodule Munchkin.Engine.Translation do
  use GenServer

  alias NimbleCSV.RFC4180, as: CSV

  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  @impl true
  def init(_args) do
    table = :ets.new(:fundamental_translations, [:set, :protected])
    Process.send_after(self(), :load_data, 500)
    {:ok, table}
  end

  def add(types, prefix), do: GenServer.cast(__MODULE__, {:add, types, prefix})
  def get(type), do: GenServer.call(__MODULE__, {:get, type})

  def translate(type), do: GenServer.call(__MODULE__, {:parse, type})

  @impl true
  def handle_info(:load_data, table) do
    _ = translation_meaning(table)

    {:noreply, table}
  end

  @impl true
  def handle_cast({:add, _types, nil}, table) do
    :logger.error("cannot add types when prefix is `nil`")

    {:noreply, table}
  end

  @impl true
  def handle_cast({:add, types, prefix}, table) do
    _ = translation_dictionary(types, prefix, table)

    {:noreply, table}
  end

  @impl true
  def handle_call({:parse, type}, _from, table) do
    with {:ok, _category} = result <- lookup_value(table, object_data(type)) do
      {:reply, result, table}
    else
      err ->
        :logger.warning("cannot parse data from key=#{inspect(type)}")
        {:reply, {:error, err}, table}
    end
  end

  @impl true
  def handle_call({:get, type}, _from, table) do
    with {:ok, value} <- lookup_value(table, type) do
      {:reply, value, table}
    else
      _ -> {:reply, nil, table}
    end
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

  defp get_formula(""), do: []
  defp get_formula(f), do: String.split(f, ",")

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

  defp translation_dictionary(types, prefix, table) do
    types
    |> Enum.map(&parse_from_ext(&1))
    |> Enum.reject(&Kernel.is_nil/1)
    |> Enum.map(fn {key, value} ->
      :ets.insert_new(table, {"#{prefix}:#{key}", value})
    end)
    |> tap(fn _ ->
      :logger.info("translation has been inserted")
      :logger.info("types are #{inspect(types)} with prefix #{prefix}")
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

  defp object_data(key), do: "parsed:#{key}"

  defp lookup_value(table, key) do
    case :ets.lookup(table, key) do
      [{^key, data}] -> {:ok, data}
      _ -> {:error, "not found"}
    end
  end
end
