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
      {:ok, _user} = data -> data
      err -> err
    end
    |> then(fn
      {:ok, user} ->
        Plug.Conn.assign(conn, :current_user, user)

      {:error, message} ->
        unauthorized(conn, message)

      _ ->
        unauthorized(conn, "cannot verify the given token")
    end)
  end

  defp unauthorized(conn, message) do
    json_string = Jason.encode!(%{type: "error", message: message, data: []})

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(401, json_string)
    |> Plug.Conn.halt()
  end

  defp get_from_database(token) do
    case Accounts.get_user_by_access_token(token) do
      {:ok, user} = data ->
        _ = Munchkin.Cache.put(token, user)
        _ = Munchkin.DelayedJob.delay(fn -> update_last_used_token(token) end)
        data

      _ ->
        {:error, "token is invalid or expired"}
    end
  end

  def get_current_user(conn) do
    Map.get(conn.assigns, :current_user)
  end

  defp update_last_used_token(token) do
    case Accounts.get_user_token(token) do
      {:ok, token} -> Accounts.update_user_token(token, %{updated_at: DateTime.utc_now(:second)})
      _ -> :ok
    end
  end
end
