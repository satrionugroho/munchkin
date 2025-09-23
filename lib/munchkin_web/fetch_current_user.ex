defmodule MunchkinWeb.FetchCurrentUser do
  use Gettext, backend: MunchkinWeb.Gettext

  alias Munchkin.Accounts

  @user_session_key "_current_admin"

  def init(opts \\ []), do: opts

  def put_admin(conn, %Accounts.Admin{email: email} = _admin) when not is_nil(email) do
    hash = Base.url_encode64(email)
    Plug.Conn.put_session(conn, @user_session_key, hash)
  end

  def put_admin(conn, _), do: conn

  def get_admin(conn) do
    case Plug.Conn.get_session(conn, @user_session_key) do
      nil -> {:error, gettext("admin not logged in")}
      hash -> {:ok, hash}
    end
  end

  def call(conn, params) do
    case Keyword.get(params, :type) do
      :cookies -> html_auth(conn)
      _ -> api_auth(conn)
    end
  end

  defp html_auth(conn) do
    case get_admin(conn) do
      {:ok, hash} -> validate_hash(conn, hash)
      _ -> redirected(conn)
    end
  end

  defp api_auth(conn) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> validate_token(conn, token)
      _ -> unauthorized(conn, gettext("must have a token"))
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
        unauthorized(conn, gettext("cannot verify the given token"))
    end)
  end

  defp validate_hash(conn, hash) do
    case Base.url_decode64(hash) do
      {:ok, email} -> get_admin_data(conn, email)
      _ -> redirected(conn)
    end
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
        {:error, gettext("token is invalid or expired")}
    end
  end

  defp get_admin_data(conn, email) do
    case Munchkin.Cache.get("email:#{email}") do
      {:ok, nil} -> get_admin_from_database(email)
      {:ok, _admin} = data -> data
      err -> err
    end
    |> then(fn
      {:ok, admin} -> Plug.Conn.assign(conn, :current_user, admin)
      _ -> redirected(conn)
    end)
  end

  defp get_admin_from_database(email) do
    case Accounts.get_admin_by_email(email) do
      %Accounts.Admin{} = admin ->
        _ = Munchkin.Cache.put("email:#{email}", admin)
        {:ok, admin}

      _ ->
        {:error, "Admin not found"}
    end
  end

  defp redirected(conn) do
    conn
    |> Phoenix.Controller.put_flash(:error, gettext("Restricted Area!. Need authenticate."))
    |> Phoenix.Controller.redirect(to: "/signin")
    |> Plug.Conn.halt()
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
