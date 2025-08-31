defmodule MunchkinWeb.API.V1.SessionJSON do
  defp do_generate_token(attrs) do
    case Munchkin.Accounts.create_user_token(attrs) do
      {:ok, user_token} -> user_token.token
      _ -> 
        raise ArgumentError, "cannot create a token"
    end
  end

  defp generate_token(user) do
    attrs = %{
      user: user,
      valid_until: DateTime.utc_now() |> DateTime.shift(day: 7),
      type: 2
    }
    do_generate_token(attrs)
  end

  defp generate_refresh_token(user) do
    attrs = %{
      user: user,
      valid_until: DateTime.utc_now() |> DateTime.shift(day: 14),
      type: 3
    }
    do_generate_token(attrs)
  end

  def render("create.json", %{user: user}) when user.verified_at != nil do
    token = generate_token(user)
    refresh = generate_refresh_token(user)

    %{
      data: %{
        user: %{
          id: user.id,
          email: user.email,
          name: "#{user.firstname} #{user.lastname}" |> String.trim()
        },
        tokens: %{
          access: token,
          refresh: refresh
        }
      },
      action: "login"
    }
  end

  def render("create.json", %{user: user, messages: messages}) do
    %{
      data: %{
        user: %{
          id: user.id,
          email: user.email,
          name: "#{user.firstname} #{user.lastname}" |> String.trim()
        },
        tokens: nil
      },
      action: "login",
      message: messages
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
