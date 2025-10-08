defmodule Munchkin.Engine.Jkse.Session do
  use GenServer

  alias Munchkin.Engine.Jkse.Config

  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  def init(_args) do
    {:ok, []}
  end

  def fetch(path, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    command = System.find_executable("node")
    execfile = Config.runtime_dir() |> Path.join("fetch.js")

    options = [
      execfile,
      "--user=#{Config.user_agent()}",
      "--browser=#{Config.driver()}",
      path
    ]

    GenServer.call(__MODULE__, {:fetch, command, options}, timeout)
  end

  def download(ticker, path, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 50_000)
    execfile = Config.runtime_dir() |> Path.join("download.js")
    command = System.find_executable("node")

    options = [
      execfile,
      path,
      "--user=#{Config.user_agent()}",
      "--browser=#{Config.driver_chrome()}",
      "--ticker=#{ticker}",
      "--timeout=#{timeout}"
    ]

    GenServer.call(__MODULE__, {:download, command, options}, timeout)
  end

  def handle_call({type, cmd, options}, _from, context) when type in [:fetch, :download] do
    with {result, 0} <- System.cmd(cmd, options),
         {:ok, _data} = data <- Config.json_module().decode(result) do
      {:reply, data, context}
    else
      _ -> {:reply, {:error, "cannot get resource"}, context}
    end
  end
end
