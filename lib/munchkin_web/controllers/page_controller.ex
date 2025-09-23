defmodule MunchkinWeb.PageController do
  use MunchkinWeb, :controller

  def home(conn, _params) do
    {:ok, total_users} = Munchkin.Dashboard.total_users()
    render(conn, :home, total_users: total_users)
  end
end
