defmodule MunchkinWeb.EndUser.SessionController do
  use MunchkinWeb, :controller

  alias Munchkin.Accounts

  plug :ensure_not_logged_in

  def index(conn, _params) do
    form = Accounts.change_user(%Accounts.User{}) |> Phoenix.Component.to_form()

    render(conn, :index, form: form, errors: [])
  end

  def create(conn, params) do
    form = Accounts.change_user(%Accounts.User{}, params) |> Phoenix.Component.to_form()

    with email <- Map.get(params, "email"),
         source <- Map.get(params, "source", "web"),
         password when is_bitstring(password) <- Map.get(params, "password"),
         otp <- Map.get(params, "code"),
         {:ok, user} <- find_user_by_email(email),
         true <- Argon2.verify_pass(password, user.password_hash) do
      Munchkin.DelayedJob.delay(fn ->
        Accounts.update_user(user, %{}, :login_changeset)
      end)

      conn
      |> MunchkinWeb.FetchCurrentUser.put_user(user)
      |> redirect(to: "/")
    else
      {:error, errors} ->
        render(conn, :index, form: form, errors: errors)
    end
  end

  defp find_user_by_email(email) do
    case Accounts.get_user_by_email(email) do
      %Accounts.User{} = user ->
        {:ok, user}

      _ ->
        :logger.warning("cannot find a user with email=#{inspect(email)}")
        :ok
    end
  end

  defp ensure_not_logged_in(conn, _opts) do
    case MunchkinWeb.FetchCurrentUser.get_current_user(conn) do
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
