defmodule MunchkinWeb.EndUser.AnalyzeLive do
  use MunchkinWeb, :live_view

  def mount(%{"ticker" => ticker}, session, socket) do
    assign_user(session, socket)
    |> assign(:ticker, ticker)
    |> ok()
  end
end
