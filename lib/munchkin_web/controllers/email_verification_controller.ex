defmodule MunchkinWeb.EmailVerificationController do
  use MunchkinWeb, :controller

  alias Munchkin.Accounts
  alias Munchkin.Accounts.UserToken

  def index(conn, params) do
    with token when is_bitstring(token) <- Map.get(params, "token"),
      %UserToken{} = user_token <- Accounts.get_user_token(token),
      true <- Kernel.==(user_token.type, 1) do

      Munchkin.DelayedJob.delay(fn ->
        Munchkin.Repo.transact(fn -> 
          Accounts.update_user_token(user_token, %{used_at: NaiveDateTime.utc_now(:second)})
          Accounts.update_user(user_token.user, %{}, :email_verified_changeset)
        end)
      end)

      render(conn, :index, user: user_token.user)
    else
      _ ->
        render(conn, :error, messages: [gettext("your token is already verified or expired")])
    end
  end
end
