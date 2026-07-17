defmodule Munchkin.Engine.Jkse.SimpleCache do
  use GenServer

  def init(_) do
    table = :ets.new(:jkse_simple_cache, [:ordered_set, :protected, :named_table])

    {:ok, table}
  end

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def put(key, value, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, :timer.minutes(10))

    GenServer.call(__MODULE__, {:put, key, value, ttl})
  end

  def get_or_update(key, fun, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, :timer.minutes(10))
    GenServer.call(__MODULE__, {:get_or_update, key, fun, ttl})
  end

  def handle_call({:get, key}, _from, table) do
    validate_data(table, key)
    |> then(fn reply ->
      {:reply, reply, table}
    end)
  end

  def handle_call({:put, key, value, ttl}, _from, table) do
    put_data(table, key, value, ttl)
    |> then(fn reply -> {:reply, reply, table} end)
  end

  def handle_call({:get_or_update, key, fun, ttl}, _from, table) do
    validate_data(table, key)
    |> case do
      :miss -> evaluate_function(table, key, fun, ttl)
      data -> data
    end
    |> then(fn reply -> {:reply, reply, table} end)
  end

  defp put_data(table, key, value, ttl) do
    expire = :erlang.system_time(:second) + ttl

    case :ets.insert_new(table, {key, value, expire}) do
      true -> {:ok, value}
      _ -> {:error, value}
    end
  end

  defp validate_data(table, key) do
    now = :erlang.system_time(:second)

    :ets.lookup(table, key)
    |> case do
      [] ->
        :miss

      [{key, value, expire}] ->
        case now > expire do
          true ->
            :ets.delete(table, key)
            :miss

          _ ->
            {:ok, value}
        end
    end
  end

  defp evaluate_function(table, key, fun, ttl) do
    apply(fun, [])
    |> case do
      [_ | _] = data -> put_data(table, key, data, ttl)
      {:ok, data} -> put_data(table, key, data, ttl)
      err -> {:error, err}
    end
  end
end
