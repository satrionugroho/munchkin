defmodule MunchkinWeb.EmailVerificationController do
  use MunchkinWeb, :controller

  alias Munchkin.{Accounts, DelayedJob, Repo}

  def index(conn, params) do
    with raw when is_bitstring(raw) <- Map.get(params, "token"),
         {:ok, user_token} <- Accounts.get_user_token(raw),
         true <- Kernel.==(user_token.type, 1),
         true <- Kernel.is_nil(user_token.used_at),
         user <- Accounts.get_user!(user_token.user_id) do
      DelayedJob.delay(fn ->
        Repo.transact(fn ->
          Accounts.update_user_token(user_token, %{used_at: DateTime.utc_now(:second)})
          Accounts.update_user(user_token.user_id, %{}, :email_verified_changeset)
        end)
      end)

      render(conn, :index, user: user)
    else
      _ ->
        render(conn, :error, messages: [gettext("your token is already verified or expired")])
    end
  end
end
