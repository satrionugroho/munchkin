defmodule MunchkinWeb.EndUser.RegistrationController do
  use MunchkinWeb, :controller

  alias Munchkin.Accounts

  def index(conn, _params) do
    form = Accounts.change_user(%Accounts.User{}) |> Phoenix.Component.to_form()
    render(conn, form: form, errors: [])
  end
end
