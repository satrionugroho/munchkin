defmodule MunchkinWeb.API.V1.UserController do
  use MunchkinWeb, :controller

  alias Munchkin.Accounts.PartialQuery
  alias Munchkin.Accounts
  alias Munchkin.Accounts.UserToken

  def index(conn, _params) do
    current_user = get_current_user(conn)
    render(conn, :index, user: current_user)
  end

  def create(conn, params) do
    with current_user <- get_current_user(conn),
         ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         rendered <- update_user(conn, current_user, params) do
      _ = Munchkin.Cache.delete(token)
      rendered
    else
      {:error, msg} ->
        render(conn, :error, messages: [msg])

      _ ->
        render(conn, :error, messages: [gettext("cannot update user")])
    end
  end

  defp update_user(conn, user, %{"action" => "two_factor"} = _params) do
    with attrs <- compose_attrs(user),
         {:ok, token} <- create_two_factor_token(user, attrs),
         updated_user <- Accounts.get_user!(token.user_id) do
      render(conn, :request_2fa, user: updated_user, token: token)
    else
      _ -> render(conn, :error, messages: [gettext("cannot request 2FA")])
    end
  end

  defp update_user(conn, user, %{"action" => "validate_two_factor"} = params) do
    user.two_factor_tokens
    |> Enum.find(&Kernel.is_nil(&1.used_at))
    |> case do
      %UserToken{} = token -> validate_mfa_token(token, params)
      _ -> {:error, gettext("token not found")}
    end
    |> then(fn
      {:ok, user} -> render(conn, :validate_2fa, user: user)
      {:error, msg} when is_bitstring(msg) -> render(conn, :error, messages: [msg])
      {:error, msg} -> render(conn, :error, messages: msg)
    end)
  end

  defp update_user(conn, user, %{"action" => "delete_two_factor", "id" => id}) do
    user.two_factor_tokens
    |> Enum.find(&String.equivalent?(to_string(&1.id), to_string(id)))
    |> case do
      %UserToken{} = token -> Accounts.delete_user_token(token)
      _ -> {:error, gettext("token not found")}
    end
    |> then(fn
      {:ok, token} -> render(conn, :delete_2fa, token: token)
      {:error, msg} when is_bitstring(msg) -> render(conn, :error, messages: [msg])
      {:error, msg} -> render(conn, :error, messages: msg)
    end)
  end

  defp update_user(conn, user, %{"new_password" => newPass} = params) when newPass != "" do
    with confirmation <- Map.get(params, "new_password_confirmation"),
         true <- String.equivalent?(confirmation, newPass),
         {:ok, options} <- validate_update_password(user, params),
         {:ok, updated_user} <- Accounts.update_user(user, options) do
      render(conn, :index, user: updated_user)
    else
      {:error, msg} when is_bitstring(msg) -> render(conn, :error, messages: [msg])
      {:error, msg} -> render(conn, :error, messages: msg)
    end
  end

  defp update_user(conn, user, params) do
    case Accounts.update_user(user, params) do
      {:ok, updated_user} -> render(conn, :index, user: updated_user)
      {:error, msg} when is_bitstring(msg) -> render(conn, :error, messages: [msg])
      {:error, msg} -> render(conn, :error, messages: msg)
    end
  end

  defp validate_update_password(%Accounts.User{email_source: "google"} = _user, _params),
    do: {:error, gettext("no need to set password for linked accounts")}

  defp validate_update_password(%Accounts.User{password_hash: hash}, %{
         "new_password" => new_password,
         "current_password" => password
       }) do
    case Argon2.verify_pass(password, hash) do
      true -> {:ok, %{password: new_password}}
      _ -> {:error, gettext("current password is not match")}
    end
  end

  defp compose_attrs(user) do
    %{
      user: user,
      valid_until: DateTime.utc_now(:second) |> DateTime.shift(minute: 10),
      type: UserToken.two_factor_type()
    }
  end

  defp validate_mfa_token(user_token, %{"code" => code}) do
    NimbleTOTP.valid?(user_token.token, code)
    |> case do
      false ->
        {:error, gettext("cannot verify the given code")}

      _ ->
        date = NaiveDateTime.utc_now() |> NaiveDateTime.shift(year: 1000)

        case Accounts.update_user_token(user_token, %{valid_until: date}) do
          {:ok, t} -> {:ok, Accounts.get_user!(t.user_id)}
          _ -> {:error, gettext("cannot update the user token")}
        end
    end
  end

  defp validate_mfa_token(_token, _), do: {:error, gettext("code not found")}

  def two_factors(conn, _params) do
    with current_user <- get_current_user(conn),
         token when not is_nil(token) <- get_active_2fa_token(current_user.two_factor_tokens) do
      render(conn, :two_factors, token: token, user: current_user)
    else
      _ ->
        render(conn, :error, messages: [gettext("cannot two factor user")])
    end
  end

  defp get_active_2fa_token(tokens) do
    next_day = DateTime.utc_now(:second) |> DateTime.shift(day: 1)

    Enum.find(tokens, fn token ->
      DateTime.after?(token.valid_until, next_day)
      |> then(fn res ->
        Kernel.is_nil(token.used_at)
        |> Kernel.and(res)
      end)
    end)
  end

  defp create_two_factor_token(user, attrs) do
    Munchkin.Repo.transact(fn ->
      query = PartialQuery.delete_unused_2fa_token(user.id)
      _ = Munchkin.Repo.delete_all(query)
      Munchkin.Accounts.create_user_token(attrs)
    end)
  end
end
