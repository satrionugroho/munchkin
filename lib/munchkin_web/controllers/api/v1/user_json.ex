defmodule MunchkinWeb.API.V1.UserJSON do
  def render("index.json", %{user: user}) do
    %{
      action: "accounts",
      data: user_data(user, two_factor_enabled?: false)
    }
  end

  def render("request_2fa.json", %{user: user, token: token}) do
    %{
      action: "request_2fa",
      data: %{
        user: user_data(user, two_factor_enabled?: false),
        token: MunchkinWeb.API.V1.UserTokenJSON.token_data(token),
        uri:
          NimbleTOTP.otpauth_uri("#{Munchkin.application_name()}:#{user.email}", token.token,
            issuer: Munchkin.application_name()
          )
      }
    }
  end

  def render("validate_2fa.json", %{user: user}) do
    %{
      action: "validate_2fa",
      data: %{
        user: user_data(user)
      }
    }
  end

  def render("delete_2fa.json", %{token: token}) do
    %{
      action: "delete_2fa",
      data: %{
        token: %{
          data: MunchkinWeb.API.V1.UserTokenJSON.token_data(token),
          deleted: true
        }
      }
    }
  end

  def render("error.json", %{messages: messages}) do
    %{
      action: "update account",
      data: nil,
      messages: messages
    }
  end

  def user_data(%Munchkin.Accounts.User{} = user, opts \\ []) do
    %{
      id: user.id,
      email: user.email,
      name: fullname(user)
    }
    |> with_two_fa?(user, Keyword.get(opts, :two_factor_enabled?, true))
  end

  defp fullname(user) do
    "#{user.firstname} #{user.lastname}"
    |> String.trim()
  end

  defp with_two_fa?(data, user, true) do
    Enum.filter(user.two_factor_tokens, &Kernel.is_nil(&1.used_at))
    |> Enum.any?()
    |> then(&Map.put(data, :two_factor, &1))
  end

  defp with_two_fa?(data, _user, _), do: data
end
