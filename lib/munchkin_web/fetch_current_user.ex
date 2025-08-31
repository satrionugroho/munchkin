defmodule MunchkinWeb.FetchCurrentUser do
  alias Munchkin.Accounts
  def init(_), do: :ok

  def call(conn, _) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> validate_token(conn, token)
        _ -> unauthorized(conn, "must have a token")
    end
  end

  defp validate_token(conn, token) do
    case Munchkin.Cache.get(token) do
      {:ok, nil} -> get_from_database(token)
      {:ok, user} -> user
        err -> err
    end
    |> then(fn 
      {:error, message} -> unauthorized(conn, message)
      %{valid_until: valid_until} = token ->
        case NaiveDateTime.compare(NaiveDateTime.utc_now(:second), valid_until) do
          :lt -> Plug.Conn.assign(conn, :current_user, Map.get(token, :user))
          _ -> unauthorized(conn, "token is not valid")
        end
    end)
  end

  defp unauthorized(conn, message) do
    Plug.Conn.send_resp(conn, 401, message)
    |> Plug.Conn.halt()
  end

  defp get_from_database(token) do
    case Accounts.get_user_token(token) do
      %Accounts.UserToken{} = user_token ->
        _ = Munchkin.Cache.put(token, user_token)
        user_token
      _ -> {:error, "cannot validate token"}
    end
  end

  def get_current_user(conn) do
    Map.get(conn.assigns, :current_user)
  end
end
