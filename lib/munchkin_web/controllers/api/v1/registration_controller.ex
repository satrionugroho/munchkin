defmodule MunchkinWeb.API.V1.RegistrationController do
  use MunchkinWeb, :controller

  def create(conn, params) do
    with {:ok, user} <- Munchkin.Accounts.create_user(params) do
      Munchkin.DelayedJob.delay(fn -> MunchkinWeb.Mailers.EmailVerificationMailer.email(user) end)

      render(conn, :create, user: user)
    else
      _ -> render(conn, :error, messages: [gettext("cannot register a user")])
    end
  end
end
