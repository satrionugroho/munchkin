defmodule MunchkinWeb.API.V1.SessionController do
  use MunchkinWeb, :controller

  alias Munchkin.Accounts
  alias Munchkin.Accounts.User
  
  def create(conn, params) do
    with email <- Map.get(params, "email"),
         password when is_bitstring(password) <- Map.get(params, "password"),
         {:ok, user} <- find_user_by_email(email),
         true <- Argon2.verify_pass(password, user.password_hash) do
      Munchkin.DelayedJob.delay(fn -> 
        Accounts.update_user(user, %{}, :success_login_changeset)
      end)
      render(conn, :create, user: user, messages: [gettext("need to verify the email")])
    else
      _ ->
        Munchkin.DelayedJob.delay(fn -> 
          maybe_update_user(params)
        end)
        render(conn, :error, messages: [gettext("Email or Password missmatch")])
    end
  end

  defp maybe_update_user(params) do
    case Map.get(params, "email") do
      nil ->
        :logger.warning("cannot find a user with email=`nil`")
        :ok
      email -> 
        case find_user_by_email(email) do
          {:ok, user} -> Accounts.update_user(user, %{}, :failed_login_changeset)
          _ -> :ok
        end
    end
  end

  defp find_user_by_email(email) do
    case Accounts.get_user_by_email(email) do
      %User{} = user -> {:ok, user}
      _ ->
        :logger.warning("cannot find a user with email=#{inspect email}")
        :ok
    end
  end
end
