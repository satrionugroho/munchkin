defmodule MunchkinWeb.API.V1.RegistrationController do
  use MunchkinWeb, :controller

  def create(conn, params) do
    with options <- markup_params(params),
         {:ok, user} <- Munchkin.Accounts.create_user(options) do
      Munchkin.DelayedJob.delay(fn -> MunchkinWeb.Mailers.EmailVerificationMailer.email(user) end)

      render(conn, :create, user: user)
    else
      {:error, %Ecto.Changeset{errors: _errors} = changeset} ->
        messages = format_changeset_errors(changeset)
        render(conn, :error, messages: messages)
    end
  end

  defp format_changeset_errors(changeset) do
    Enum.map(changeset.errors, fn {field, error_message} ->
      field_name = field |> Atom.to_string() |> String.capitalize()

      case error_message do
        {format_string, interpolations} ->
          formatted_message =
            String.replace(
              format_string,
              "%{count}",
              Keyword.get(interpolations, :count, 0) |> to_string
            )

          "#{field_name} #{formatted_message}"

        message when is_binary(message) ->
          "#{field_name} #{message}"

        _ ->
          "#{field_name} has an unknown error"
      end
    end)
  end

  defp markup_params(%{"email_source" => _email} = params), do: params
  defp markup_params(params), do: Map.put(params, "email_source", "email")
end
