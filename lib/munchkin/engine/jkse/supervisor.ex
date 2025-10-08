defmodule Munchkin.Engine.Jkse.Supervisor do
  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      Munchkin.Engine.Jkse.Session,
      Munchkin.Engine.Jkse.Fundamental.Translation,
      Munchkin.Engine.Jkse.Instance
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
