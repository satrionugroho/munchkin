defmodule Munchkin.Accounts.Integration do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  schema "user_integrations" do
    field :idempotency_id, :string
    field :provider, :string

    belongs_to :user, Munchkin.Accounts.User
  end

  def changeset(integration, attrs) do
    params = Enum.reduce(attrs, %{}, fn {key, val}, acc -> Map.put(acc, to_string(key), val) end)

    integration
    |> cast(params, [:idempotency_id, :provider])
    |> validate_required([:idempotency_id, :provider])
    |> should_put_user(params)
  end

  defp should_put_user(changeset, params) do
    case get_field(changeset, :user) do
      %Munchkin.Accounts.User{} = _data ->
        changeset

      _ ->
        case get_field(changeset, :user_id) do
          nil -> put_user(changeset, params)
          _ -> changeset
        end
    end
  end

  defp put_user(changeset, %{"user" => %Munchkin.Accounts.User{} = user}),
    do: put_change(changeset, :user, user)

  defp put_user(changeset, %{"user_id" => id}) do
    String.to_integer(id)
    |> Munchkin.Accounts.get_user()
    |> case do
      %Munchkin.Accounts.User{} = user -> put_change(changeset, :user, user)
      _ -> add_error(changeset, :user, "cannot put user")
    end
  end
end
