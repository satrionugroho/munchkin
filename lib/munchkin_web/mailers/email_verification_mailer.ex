defmodule MunchkinWeb.Mailers.EmailVerificationMailer do
  use MunchkinWeb,
    type: :mailer,
    view: MunchkinWeb.Mailers.View,
    engine: MunchkinWeb.Mailers

  def email(user) do
    attrs = %{
      user: user,
      valid_until: DateTime.utc_now() |> DateTime.shift(day: 2),
      type: Munchkin.Accounts.UserToken.email_verification_type()
    }

    case Munchkin.Accounts.create_user_token(attrs) do
      {:ok, token} ->
        do_send_email(user, token)

      err ->
        :logger.error("cannot send verification email")
        :logger.error("the detailed error is #{inspect(err)}")
        :ok
    end
  end

  defp do_send_email(user, user_token) do
    fullname = "#{user.firstname} #{user.lastname}" |> String.trim()

    new()
    |> to({fullname, user.email})
    |> from(sender())
    |> subject("Account Verifications")
    |> render_body(:welcome, %{
      fullname: fullname,
      token_url: compose_url(user_token),
      title: gettext("Welcome onboard")
    })
    |> deliver()
  end

  defp compose_url(token) do
    valid_token = MunchkinWeb.Utils.decode_token(token)

    MunchkinWeb.Endpoint.url()
    |> Kernel.<>("/accounts/verification")
    |> Kernel.<>("?token=#{valid_token}")
  end
end
