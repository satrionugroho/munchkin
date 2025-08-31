defmodule MunchkinWeb.API.V1.UserController do
  use MunchkinWeb, :controller

  alias Munchkin.Accounts

  def index(conn, _params) do
    current_user = get_current_user(conn)
    render(conn, :index, user: current_user)
  end

  def update(conn, params) do
    with current_user <- get_current_user(conn),
      ["Bearer " <> token] <- get_req_header(conn, "authorization"),
      {:ok, updated_user} <- update_user(current_user, params) do
      Munchkin.Cache.delete(token)
      render(conn, :index, user: updated_user, message: gettext("user was updated sucessfully"))
    else
      _ ->
      render(conn, :error, message: gettext("cannot update user"))
    end
  end

  def update_user(user, %{"action" => "two_factor"} = _params) do
    attrs = %{
      user: user,
      valid_until: DateTime.utc_now() |> DateTime.shift(minute: 60),
      type: 5
    }

    case Accounts.create_user_token(attrs) do
      {:ok, _token} -> {:ok, Munchkin.Repo.preload(user, [:user_tokens])}
      err -> err
    end
  end

  def update_user(user, %{"action" => "validate_two_factor"} = params) do
    user.user_tokens
    |> Enum.filter(&Kernel.==(&1.type, Accounts.UserToken.two_factor_type()))
    |> case do
      [token | _rest] -> validate_mfa_token(token, params)
        _ -> {:error, gettext("token not found")}
    end
  end

  def update_user(user, %{"action" => "delete_two_factor"} = _params) do
    user.user_tokens
    |> Enum.filter(&Kernel.==(&1.type, Accounts.UserToken.two_factor_type()))
    |> case do
      [token | _rest] -> Accounts.delete_user_token(token)
        _ -> {:error, gettext("token not found")}
    end
  end

  def update_user(user, params) do
    Accounts.update_user(user, params)
  end

  defp validate_mfa_token(user_token, %{"code" => code}) do
    Base.url_decode64!(user_token.token)
    |> NimbleTOTP.valid?(code, period: 60)
    |> case do
      false -> {:error, gettext("cannot verify the given code")}
      _ ->
        date = NaiveDateTime.utc_now() |> NaiveDateTime.shift(year: 1000)

        case Accounts.update_user_token(user_token, %{valid_until: date}) do
          {:ok, t} -> {:ok, Accounts.get_user!(t.user_id)}
          _ -> {:error, gettext("cannot update the user token")}
        end
    end
  end
  defp validate_mfa_token(_token, _), do: {:error, gettext("code not found")}

end
