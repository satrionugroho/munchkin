defmodule Munchkin.Mailer.EmailVerificator do
  import Swoosh.Email

  def email(user) do
    attrs = %{
      user: user,
      valid_until: DateTime.utc_now() |> DateTime.shift(minute: 60),
      type: 1
    }

    case Munchkin.Accounts.create_user_token(attrs) do
      {:ok, token} -> do_send_email(user, token)
      err ->
        :logger.error("cannot send verification email")
        :logger.error("the detailed error is #{inspect err}")
        :ok
    end
  end

  def do_send_email(user, user_token) do
    fullname = "#{user.firstname} #{user.lastname}" |> String.trim()

    new()
    |> to({fullname, user.email})
    |> from(Munchkin.Mailer.sender())
    |> subject("Account Verifications")
    |> html_body("<h1>Hello #{user.firstname}</h1><br /><p>You can verify your account by clicking <a href='#{MunchkinWeb.Endpoint.url()}/accounts/verification?token=#{user_token.token}'>this link</a></p>")
    |> text_body("Hello #{fullname}\n")
    |> Munchkin.Mailer.deliver()
  end

end
