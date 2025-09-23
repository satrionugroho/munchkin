defmodule MunchkinWeb.UserController do
  alias Munchkin.Accounts
  use MunchkinWeb, :controller

  def index(conn, params) do
    opts = parse_search_params(params)
    limit = Keyword.get(opts, :per, 10)
    term = Keyword.get(opts, :q, "")
    users = Accounts.list_users(opts)
    render(conn, :index, data: users, limit: limit, search_term: term)
  end

  def show(conn, %{"id" => id}) do
    with %Accounts.User{} = user <-
           Accounts.get_user(id, [:two_factor_tokens, :subscriptions]),
         form <- html_form(%Munchkin.Subscription.Payment{}),
         tier <- Munchkin.Subscription.define_product(user, Munchkin.Subscription.free_tier!()) do
      IO.inspect(tier)
      render(conn, :show, user: user, tier: tier, date_format: "%Y-%m-%d", form: form)
    else
      _ -> render(conn, :not_found)
    end
  end
end
