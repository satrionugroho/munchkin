defmodule Munchkin.Engine.Jkse.Supervisor do
  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      Munchkin.Engine.Jkse.Session,
      Munchkin.Engine.Jkse.Instance
    ]

    pid =
      spawn(fn ->
        receive do
          :load_translation ->
            Munchkin.Engine.Jkse.Fundamental.Type.available_types()
            |> Munchkin.Engine.Translation.add("idx")

          err ->
            :logger.warning("IDX translation cannot load due to error #{inspect(err)}")
        after
          2000 ->
            :logger.warning("Timed out when waiting message from IDX translation")
        end
      end)

    Process.send_after(pid, :load_translation, 1000)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
