defmodule MunchkinWeb.PageController do
  use MunchkinWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
