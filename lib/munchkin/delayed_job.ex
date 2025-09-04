defmodule Munchkin.DelayedJob do
  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def init(_arg), do: {:ok, []}

  def delay(fun) do
    GenServer.cast(__MODULE__, {:execution, fun})
  end

  def handle_cast({:execution, fun}, state) do
    case apply(fun, []) do
      :ok ->
        {:noreply, state}

      {:ok, _ret} ->
        {:noreply, state}

      err ->
        :logger.debug("[delayed] execution returned #{inspect(err)}")
        Process.send_after(self(), :retry, 1000)
        {:noreply, [state | fun]}
    end
  end

  def handle_info(:retry, []) do
    {:noreply, []}
  end

  def handle_info(:retry, [fun | tail]) do
    Process.send_after(self(), :retry, 1000)

    ret = apply(fun, [])
    :logger.debug("[delayed] last retry returned #{inspect(ret)}")
    {:noreply, tail}
  end
end
