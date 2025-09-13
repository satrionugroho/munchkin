defmodule MunchkinWeb.API.V1.RegistrationJSON do
  def render("create.json", %{user: user}) do
    %{
      data: %{
        id: user.id,
        email: user.email,
        name: "#{user.firstname} #{user.lastname}" |> String.trim()
      },
      messages: [],
      action: "register"
    }
  end

  def render("error.json", %{messages: messages}) do
    %{
      data: nil,
      action: "register",
      messages: messages
    }
  end
end
