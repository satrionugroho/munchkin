defmodule Munchkin.Downloader do
  use GenServer

  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  @impl true
  def init(_args) do
    {:ok, []}
  end

  def download(mfa, opts \\ []) do
    GenServer.cast(__MODULE__, {:download, mfa, opts})
  end

  @impl true
  def handle_cast({:download, mfa_or_fun, opts}, state) do
    id = Ecto.UUID.generate()
    Process.send_after(self(), :execute, 2000)
    {:noreply, [{id, mfa_or_fun, opts} | state]}
  end

  @impl true
  def handle_info(:execute, [head | tail]) do
    {id, mfa_or_fun, _opts} = head

    case executed(mfa_or_fun) do
      :ok -> log_ok(id, tail)
      {:ok, _data} -> log_ok(id, tail)
      err -> log_err(err, tail, head)
    end
  end

  def handle_info(:execute, _), do: {:noreply, []}

  defp executed({module, fun, args}) do
    apply(module, fun, args)
  end

  defp executed(fun) do
    apply(fun, [])
  end

  defp log_ok(id, tail) do
    :logger.info("The function is executed sucessfully with id=#{inspect(id)}")
    {:noreply, tail}
  end

  defp log_err(err, tail, head) do
    {id, mfa_or_fun, opts} = head

    :logger.error("The given function executed with error=#{inspect(err)} id=#{inspect(id)}")

    case Keyword.get(opts, :retry) do
      num when is_number(num) and num > 3 ->
        :logger.error("The given id=#{id} cannot continue do broken function.")
        :logger.error("The function specification is #{inspect(mfa_or_fun)}")
        {:noreply, tail}

      num when is_number(num) ->
        :logger.info("We try to add the broken function to the queue with num=#{num}")
        state = List.flatten([tail, {id, mfa_or_fun, [retry: num + 1]}])
        {:noreply, state}

      _ ->
        :logger.info("We retry the failed function")
        state = List.flatten([tail, {id, mfa_or_fun, [retry: 1]}])
        {:noreply, state}
    end
  end
end
