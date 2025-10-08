defmodule Munchkin.Engine do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Munchkin.Engine.Jkse.Supervisor
    ]

    opts = [strategy: :one_for_one, name: Munchkin.Engine.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start, [nil, opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end
end
