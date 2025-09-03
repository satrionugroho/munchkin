defmodule MunchkinWeb.API.V1.SessionController do
  use MunchkinWeb, :controller

  alias Munchkin.Accounts
  alias Munchkin.Accounts.User
  alias Munchkin.Accounts.UserToken

  def create(conn, params) do
    with email <- Map.get(params, "email"),
         password when is_bitstring(password) <- Map.get(params, "password"),
         otp <- Map.get(params, "code"),
         {:ok, user} <- find_user_by_email(email),
         true <- Argon2.verify_pass(password, user.password_hash),
         {:ok, tokens} <- maybe_create_user_token(user, otp) do
      Munchkin.DelayedJob.delay(fn ->
        Accounts.update_user(user, %{}, :success_login_changeset)
      end)

      render(conn, :create,
        user: user,
        tokens: tokens,
        messages: [gettext("need to verfy the email")]
      )
    else
      {:retry, user, messages} -> render(conn, :create, user: user, tokens: nil, messages: messages)
      _ ->
        Munchkin.DelayedJob.delay(fn -> maybe_update_user(params) end)

        render(conn, :error, messages: [gettext("Email or Password missmatch")])
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
          {:ok, user} -> Accounts.update_user(user, %{}, :failed_login_changeset)
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
    user.user_tokens
    |> Enum.find(&Kernel.==(&1.type, UserToken.two_factor_type()))
    |> case do
      %UserToken{} = token -> should_verify_the_otp(user, token, otp)
      _ -> should_create_user_token(user)
    end
  end
  defp maybe_create_user_token(_, _), do: {:ok, nil}

  defp should_create_user_token(user) do
    case Accounts.create_user_access_token(user) do
      {:ok, tokens} -> {:ok, tokens}
      _ -> maybe_create_user_token(nil, nil)
    end
  end

  defp should_verify_the_otp(user, token, otp) when not is_nil(otp) do
    case NimbleTOTP.valid?(token.token, otp) do
      true -> should_create_user_token(user)
      _ -> {:error, gettext("cannot verify the otp token")}
    end
  end
  defp should_verify_the_otp(user, _token, _otp), do: {:retry, user, [gettext("should enter the otp")]}


  defp send_forgot_password_email(user, token) do
    MunchkinWeb.Mailers.ForgotPasswordMailer.send_email(user, token)
  end
end
