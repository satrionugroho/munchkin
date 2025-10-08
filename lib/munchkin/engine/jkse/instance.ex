defmodule Munchkin.Engine.Jkse.Instance do
  alias Munchkin.Engine.Jkse.Config
  use GenServer

  def start_link(init_arg), do: GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)

  def init(_args) do
    Process.send_after(self(), :get_instance, 1000)
    {:ok, nil}
  end

  def get do
    GenServer.call(__MODULE__, :get_instance)
  end

  def handle_call(:get_instance, _from, state), do: {:reply, state, state}

  def handle_info(:get_instance, nil) do
    Config.config()
    |> Keyword.get(:instance)
    |> case do
      {mod, fun} -> do_get_instance(mod, fun)
      _ -> :logger.warning("cannot configure the instance due to unconfigured fetcher")
    end
  end

  def handle_info(:get_instance, state) do
    :logger.info("Instance already loaded")
    {:noreply, state}
  end

  defp do_get_instance(mod, fun) do
    Ecto.Repo.all_running()
    |> case do
      [] ->
        :logger.warning("Ecto is not ready yet. Postpone another 1second")
        Process.send_after(self(), :get_instance, 1000)
        {:noreply, nil}

      _ ->
        apply(mod, fun, [Config.app_id()])
        |> then(fn
          nil ->
            :logger.error("cannot get the instance. Stopping!.")

          data ->
            :logger.info("instance is ready")
            {:noreply, data}
        end)
    end
  end
end
