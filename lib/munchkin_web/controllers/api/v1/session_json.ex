defmodule MunchkinWeb.API.V1.SessionJSON do
  def render("create.json", %{user: user, tokens: tokens}) when user.verified_at != nil do
    %{
      data: %{
        user: user_data(user),
        tokens: token_view(tokens)
      },
      action: "login"
    }
  end

  def render("create.json", %{user: user, messages: messages}) do
    %{
      data: %{
        user: user_data(user),
        tokens: nil
      },
      action: "login",
      message: messages
    }
  end

  def render("forgot_password.json", %{user: user}) do
    %{
      data: %{
        user: user_data(user)
      },
      action: "forgot password"
    }
  end

  def render("forgot_password_error.json", %{messages: messages}) do
    %{
      data: %{},
      messages: messages,
      action: "forgot password"
    }
  end

  def render("forgot_password_request.json", %{messages: messages}) do
    %{
      data: %{},
      messages: messages,
      action: "forgot password request"
    }
  end

  def render("error.json", %{messages: messages}) do
    %{
      data: nil,
      action: "login",
      message: messages
    }
  end

  defp token_view(%{access: access, refresh: refresh}) do
    %{
      access: individual_token(access),
      refresh: individual_token(refresh)
    }
  end

  defp individual_token(%Munchkin.Accounts.UserToken{} = token) do
    token.token
  end

  defp user_data(user) do
    %{
      id: user.id,
      email: user.email,
      name: fullname(user),
      two_factor: two_factor_enabled?(user)
    }
  end

  defp fullname(user) do
    "#{user.firstname} #{user.lastname}"
    |> String.trim()
  end

  defp two_factor_enabled?(user) do
    Enum.filter(user.user_tokens, &Kernel.==(&1.type, Munchkin.Accounts.UserToken.two_factor_type()))
    |> Enum.any?()
  end
end
