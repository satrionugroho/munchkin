defmodule MunchkinWeb.AdminController do
  alias Munchkin.Accounts
  use MunchkinWeb, :controller

  def index(conn, params) do
    opts = parse_search_params(params)
    limit = Keyword.get(opts, :per, 10)
    term = Keyword.get(opts, :q, "")
    admins = Accounts.list_admins(opts)

    render(conn, :index, admins: admins, limit: limit, search_term: term)
  end

  def new(conn, _params) do
    form = Accounts.change_admin(%Accounts.Admin{}) |> Phoenix.Component.to_form()
    render(conn, :new, form: form, errors: [])
  end

  def create(conn, params) do
    form = Accounts.change_admin(%Accounts.Admin{}, params) |> Phoenix.Component.to_form()

    with {:ok, _admin} <- Accounts.create_admin(params) do
      conn
      |> put_flash(:info, gettext("Admin registered sucessfully"))
      |> redirect(to: ~p"/admins")
    else
      {:error, errors} ->
        render(conn, :index, form: form, errors: errors)
    end
  end
end
