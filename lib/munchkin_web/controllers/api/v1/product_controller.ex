defmodule MunchkinWeb.API.V1.ProductController do
  use MunchkinWeb, :controller

  def index(conn, params) do
    lang = Map.get(params, "lang", "en")
    data = Munchkin.Subscription.list_products(lang)
    render(conn, :index, data: data)
  end
end
