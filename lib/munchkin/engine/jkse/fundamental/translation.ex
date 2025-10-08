defmodule Munchkin.Engine.Jkse.Fundamental.Translation do
  use GenServer

  alias NimbleCSV.RFC4180, as: CSV

  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  @impl true
  def init(_args) do
    table = :ets.new(:fundamental_translations, [:set, :protected])
    Process.send_after(self(), :load_data, 500)

    {:ok, table}
  end

  defp parse!() do
    Munchkin.Engine.Jkse.Fundamental.Type.available_types()
    |> Enum.map(&parse_from_csv/1)
    |> Enum.reject(&Kernel.is_nil/1)
    |> Enum.into(%{})
  end

  defp parse_from_csv(name) do
    with file <- get_relative(name),
         true <- File.exists?(file),
         data <- load_csv(file) do
      {name, data}
    else
      false ->
        :logger.warning("cannot load file")
        nil
    end
  end

  defp get_relative(path) do
    :code.priv_dir(:munchkin)
    |> Kernel.to_string()
    |> Path.join("/data/#{path}.csv")
  end

  defp load_csv(file) do
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

  def get(key) do
    case GenServer.call(__MODULE__, {:get, key}) do
      {:ok, data} ->
        data

      _ ->
        :logger.warning("cannot get #{key} translation")
        %{}
    end
  end

  def reload!, do: GenServer.cast(__MODULE__, :reload)

  defp get_formula(""), do: []
  defp get_formula(f), do: String.split(f, ",")

  @impl true
  def handle_call({:get, key}, _from, table) do
    case :ets.lookup(table, key) do
      [{^key, data}] -> {:reply, {:ok, data}, table}
      _ -> {:reply, {:error, "translation not found"}, table}
    end
  end

  @impl true
  def handle_info(:load_data, table) do
    parse!()
    |> Enum.map(fn {key, value} ->
      :ets.insert_new(table, {key, value})
    end)

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
end
