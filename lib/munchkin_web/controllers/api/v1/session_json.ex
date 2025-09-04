defmodule MunchkinWeb.API.V1.SessionJSON do
  def render("create.json", %{user: user, tokens: tokens}) when user.verified_at != nil do
    %{
      data: %{
        user: MunchkinWeb.API.V1.UserJSON.user_data(user),
        tokens: MunchkinWeb.API.V1.UserTokenJSON.session_tokens(tokens)
      },
      action: "login"
    }
  end

  def render("create.json", %{user: user, messages: messages}) do
    %{
      data: %{
        user: MunchkinWeb.API.V1.UserJSON.user_data(user),
        tokens: nil
      },
      action: "login",
      message: messages
    }
  end

  def render("retry.json", %{user: user, messages: messages}) do
    %{
      data: %{
        user: MunchkinWeb.API.V1.UserJSON.user_data(user),
        tokens: nil
      },
      action: "login",
      message: messages
    }
  end

  def render("forgot_password.json", %{user: user}) do
    %{
      data: %{
        user: MunchkinWeb.API.V1.UserJSON.user_data(user, two_factor_enabled?: false)
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
end
