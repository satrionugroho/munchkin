defmodule Munchkin.Rotator do
  use GenServer

  def start_link(initial) do
    GenServer.start_link(__MODULE__, initial)
  end

  def init({ticker, start, lag}) do
    {:ok, %{ticker: ticker, end_period: start, start_period: start - lag}}
  end

  def handle_call(:get, _, socket) do
    {:reply, socket, socket}
  end
end
