defmodule Munchkin.Accounts.UserToken do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_tokens" do
    field :token, :string
    field :valid_until, :naive_datetime
    field :used_at, :naive_datetime
    field :type, :integer

    belongs_to :user, Munchkin.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_token, attrs) do
    user_token
    |> cast(attrs, [:valid_until, :used_at, :type])
    |> assign_user(Map.get(attrs, :user))
    |> validate_required([:valid_until, :type])
    |> validate_inclusion(:type, 1..5)
    |> create_token()
  end

  defp assign_user(changeset, user) when is_nil(user),
    do: add_error(changeset, :user, "cannot be nil")

  defp assign_user(changeset, user) do
    case get_field(changeset, :user_id) do
      nil ->
        put_change(changeset, :user, user)
        |> validate_required([:user])

      _ ->
        changeset
    end
  end

  defp create_token(changeset) do
    case get_field(changeset, :token) do
      nil ->
        type = get_field(changeset, :type)
        put_change(changeset, :token, generated_token(type))

      _ ->
        changeset
    end
  end

  defp generated_token("5") do
    NimbleTOTP.secret(20)
    |> Base.url_encode64()
  end

  defp generated_token(type) do
    len = Map.get(variants(), to_string(type))

    :rand.bytes(len)
    |> Base.url_encode64()
  end

  defp variants do
    %{
      # email verification
      "1" => 32,
      # access token
      "2" => 48,
      # refresh token
      "3" => 64,
      # forgot password
      "4" => 32,
      # subscription
      "6" => 32,
    }
  end

  def email_verification_type, do: 1
  def access_token_type, do: 2
  def refresh_token_type, do: 3
  def forgot_password_type, do: 4
  def two_factor_type, do: 5
  def subscription_type, do: 6
end
