defmodule MunchkinWeb.API.V1.UserJSON do
  
  def render("index.json", %{user: user}) do
    %{
      action: "accounts",
      data: %{
        firstname: user.firstname,
        lastname: user.lastname,
        email: user.email,
        id: user.id,
        two_factor: Enum.filter(user.user_tokens, &Kernel.==(&1.type, Munchkin.Accounts.UserToken.two_factor_type())) |> Enum.any?()
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
end
