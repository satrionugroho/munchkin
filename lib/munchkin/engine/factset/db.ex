defmodule Munchkin.Engine.Factset.DB do
  @config Application.compile_env(:munchkin, Munchkin.Engine.Factset, [])

  use GenServer

  alias Munchkin.Engine.Factset.Repo

  def start_link(arg), do: GenServer.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg) do
    case Application.get_env(:munchkin, Repo) do
      [_ | _] ->
        Supervisor.start_child(Repo, strategy: :one_for_one)
        {:ok, {:db, []}}

      _ ->
        {:ok, {:file, []}}
    end
  end

  def type, do: GenServer.call(__MODULE__, :type)

  def put_file(file) do
    GenServer.call(__MODULE__, {:file, file})
  end

  def files, do: GenServer.call(__MODULE__, :get)

  def config, do: @config
  def app_id, do: Keyword.get(@config, :database_id)

  def query(fun, args) do
    GenServer.call(__MODULE__, {:query, fun, args})
  end

  @impl true
  def handle_call({:file, file}, _from, {:file, data}) do
    {:reply, file, {:file, [file | data]}}
  end

  @impl true
  def handle_call({:file, _}, _from, state) do
    :logger.warning("cannot use file source. Use the DB instead")
    {:reply, {:error, "cannot add file"}, state}
  end

  @impl true
  def handle_call(:get, _from, {:file, files} = state) do
    {:reply, files, state}
  end

  @impl true
  def handle_call(:get, _from, state) do
    :logger.warning("files is empty because of connection using a database.")
    {:reply, nil, state}
  end

  @impl true
  def handle_call({:query, fun, args}, _from, {:db, _} = state) do
    {:reply, apply(Repo, fun, args), state}
  end

  @impl true
  def handle_call({:query, _fun, _args}, _from, state) do
    :logger.warning("cannot query from files")
    {:reply, nil, state}
  end

  @impl true
  def handle_call(:type, _from, {type, _} = state) do
    case type do
      :db -> {:reply, {type, Munchkin.Engine.Factset.DBConnection}, state}
      _ -> {:reply, {type, Munchkin.Engine.Factset.Local}, state}
    end
  end
end
