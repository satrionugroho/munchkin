defmodule MunchkinWeb.SessionController do
  use MunchkinWeb, :controller

  plug :ensure_not_logged_in

  alias Munchkin.Accounts

  def index(conn, _params) do
    form = Accounts.change_admin(%Accounts.Admin{}) |> Phoenix.Component.to_form()
    render(conn, :index, form: form, errors: [])
  end

  def create(conn, params) do
    form = Accounts.change_admin(%Accounts.Admin{}, params) |> Phoenix.Component.to_form()

    with {:ok, admin} <- Accounts.admin_session(params) do
      conn
      |> MunchkinWeb.FetchCurrentUser.put_admin(admin)
      |> redirect(to: "/")
    else
      {:error, errors} ->
        render(conn, :index, form: form, errors: errors)
    end
  end

  defp ensure_not_logged_in(conn, _opts) do
    case MunchkinWeb.FetchCurrentUser.get_admin(conn) do
      {:ok, _hash} ->
        conn
        |> put_flash(:error, gettext("already signed in"))
        |> redirect(to: "/")
        |> halt()

      _ ->
        conn
    end
  end
end
