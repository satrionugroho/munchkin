defmodule MunchkinWeb.EndUser.HomeController do
  use MunchkinWeb, :controller

  def index(conn, _params) do
    get_current_user(conn)
    |> IO.inspect()

    render(conn, :index)
  end
end
