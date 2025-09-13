defmodule MunchkinWeb.API.V1.UserTokenJSON do
  def token_data(%Munchkin.Accounts.UserToken{} = token) do
    MunchkinWeb.Utils.decode_token(token)
  end

  def token_data(str), do: str

  def session_tokens(%{access: access, refresh: refresh}) do
    %{
      access: token_data(access),
      refresh: token_data(refresh)
    }
  end
end
