defmodule MunchkinWeb.Mailers.ForgotPasswordMailer do
  use MunchkinWeb,
    type: :mailer,
    view: MunchkinWeb.Mailers.View,
    engine: MunchkinWeb.Mailers

  def send_email(user, token) do
    fullname = "#{user.firstname} #{user.lastname}" |> String.trim()

    new()
    |> to({fullname, user.email})
    |> from(sender())
    |> subject("Reset your password")
    |> render_body(:forgot_password, %{fullname: fullname, token_url: compose_url(token)})
    |> deliver()
  end

  defp compose_url(token) do
    valid_token = Base.url_encode64(token.token)

    MunchkinWeb.Endpoint.url()
    |> Kernel.<>("/forgot-password?token=#{valid_token}")
  end
end
