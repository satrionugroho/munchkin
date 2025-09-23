defmodule MunchkinWeb.API.V1.SessionController do
  use MunchkinWeb, :controller

  alias Munchkin.Subscription
  alias Munchkin.DelayedJob
  alias Munchkin.Repo
  alias Munchkin.Accounts
  alias Munchkin.Accounts.User
  alias Munchkin.Accounts.UserToken

  def create(conn, %{"refresh_token" => raw}) when not is_nil(raw) do
    with {:ok, token} <- Base.url_decode64(raw),
         {:ok, user} <- Accounts.get_user_by_refresh_token(token),
         {:ok, tokens} <- generate_new_token(user, token) do
      render(conn, :create,
        user: user,
        tokens: tokens
      )
    else
      {:error, message} ->
        put_status(conn, 403)
        |> render(:error, messages: [message])
    end
  end

  def create(conn, %{"type" => "google_auth"} = params) do
    with raw when not is_nil(raw) <- Map.get(params, "token"),
         encoded <- URI.decode(raw),
         {:ok, token} <- Base.decode64(encoded),
         {:ok, raw_user} <- Accounts.find_or_create_user(token),
         %Accounts.User{} = user <- Accounts.get_user(raw_user.id),
         {:ok, tokens} <- maybe_create_user_token(user, nil) do
      Munchkin.DelayedJob.delay(fn ->
        Accounts.update_user(user, %{}, :login_changeset)
      end)

      render(conn, :create,
        user: user,
        tokens: tokens
      )
    end
  end

  def create(conn, params) do
    with email <- Map.get(params, "email"),
         password when is_bitstring(password) <- Map.get(params, "password"),
         otp <- Map.get(params, "code"),
         {:ok, user} <- find_user_by_email(email),
         true <- Argon2.verify_pass(password, user.password_hash),
         {:ok, tokens} <- maybe_create_user_token(user, otp) do
      Munchkin.DelayedJob.delay(fn ->
        Accounts.update_user(user, %{}, :login_changeset)
      end)

      render(conn, :create,
        user: user,
        tokens: tokens,
        messages: [gettext("need to verfy the email")]
      )
    else
      {:retry, user, messages} ->
        put_status(conn, 200)
        |> render(:retry, user: user, messages: messages)

      _ ->
        Munchkin.DelayedJob.delay(fn -> maybe_update_user(params) end)

        put_status(conn, 403)
        |> render(:error, messages: [gettext("Email or Password missmatch")])
    end
  end

  def forgot_password_request(conn, params) do
    with email <- Map.get(params, "email"),
         {:ok, user} <- find_user_by_email(email),
         {:ok, token} <- Accounts.create_user_forgot_password_token(user) do
      Munchkin.DelayedJob.delay(fn -> send_forgot_password_email(user, token) end)

      render(conn, :forgot_password_request,
        messages: [gettext("an email was sent to given address if email exists")]
      )
    else
      _ ->
        render(conn, :forgot_password_request,
          messages: [gettext("an email was sent to given address if email exists")]
        )
    end
  end

  def forgot_password(conn, params) do
    with token <- Map.get(params, "token"),
         password <- Map.get(params, "password"),
         password_confirmation <- Map.get(params, "password_confirmation"),
         true <- Kernel.==(password, password_confirmation),
         {:ok, user} <- Accounts.reset_password_from_token(token, password) do
      render(conn, :forgot_password, user: user)
    else
      false ->
        render(conn, "forgot_password_error.json",
          messages: [gettext("given password and it's confirmation is not valid")]
        )

      _ ->
        render(conn, "forgot_password_error.json",
          messages: [gettext("error due to resetting the password")]
        )
    end
  end

  defp maybe_update_user(params) do
    case Map.get(params, "email") do
      nil ->
        :logger.warning("cannot find a user with email=`nil`")
        :ok

      email ->
        case find_user_by_email(email) do
          {:ok, user} -> Accounts.update_user(user, %{}, :login_changeset)
          _ -> :ok
        end
    end
  end

  defp find_user_by_email(email) do
    case Accounts.get_user_by_email(email) do
      %User{} = user ->
        {:ok, user}

      _ ->
        :logger.warning("cannot find a user with email=#{inspect(email)}")
        :ok
    end
  end

  defp maybe_create_user_token(%User{verified_at: date} = user, otp) when date != nil do
    user.two_factor_tokens
    |> Enum.find(&Kernel.is_nil(&1.used_at))
    |> case do
      %UserToken{} = token -> should_verify_the_otp(user, token, otp)
      _ -> should_create_user_token(user)
    end
  end

  defp maybe_create_user_token(_user, _otp), do: {:ok, nil}

  defp should_create_user_token(user) do
    case Accounts.create_user_access_token(user) do
      {:ok, tokens} -> {:ok, tokens}
      _ -> maybe_create_user_token(nil, nil)
    end
  end

  defp should_verify_the_otp(user, token, otp) when not is_nil(otp) do
    NimbleTOTP.valid?(token.token, otp)
    |> case do
      true -> should_create_user_token(user)
      _ -> {:error, gettext("cannot verify the otp token")}
    end
  end

  defp should_verify_the_otp(user, _token, _otp),
    do: {:retry, user, [gettext("should enter the otp")]}

  defp send_forgot_password_email(user, token) do
    MunchkinWeb.Mailers.ForgotPasswordMailer.send_email(user, token)
  end

  defp generate_new_token(user, token) do
    user.refresh_tokens
    |> Enum.find(&Kernel.==(&1.token, token))
    |> case do
      %UserToken{} = token ->
        Repo.transact(fn ->
          Accounts.update_user_token(token, %{used_at: NaiveDateTime.utc_now(:second), user: user})

          should_create_user_token(user)
        end)

      _ ->
        {:error, "cannot find the refresh token"}
    end
  end

  def verify_email(conn, params) do
    with raw when is_bitstring(raw) <- Map.get(params, "token"),
         {:ok, token} <- Accounts.get_user_token(raw),
         {:ok, true} <- verify_user_token(token),
         %User{} = user <- Accounts.get_user(token.user_id) do
      DelayedJob.delay(fn -> execute_delayed_job(token) end)
      render(conn, :verify_email, user: user)
    else
      {:error, msg} when is_bitstring(msg) ->
        render(conn, :error, messages: [msg])

      {:error, msg} ->
        render(conn, :error, messages: msg)

      {:ok, false} ->
        render(conn, :error, messages: [gettext("Token is already used")])

      err ->
        IO.inspect(err)
        render(conn, :error, messages: [gettext("error while reading the token")])
    end
  end

  defp verify_user_token(%{used_at: date, type: token_type} = _token) do
    case token_type == UserToken.email_verification_type() do
      true -> {:ok, is_nil(date)}
      _ -> {:error, "token is not valid"}
    end
  end

  defp execute_delayed_job(user_token) do
    Repo.transact(fn ->
      Accounts.update_user(user_token.user_id, %{}, :email_verified_changeset)
      Accounts.update_user_token(user_token, %{used_at: DateTime.utc_now(:second)})

      Subscription.create_subscription(%{
        user_id: user_token.user_id,
        product_id: Subscription.free_tier!().id
      })
    end)
  end
end
