defmodule Munchkin.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :firstname, :string
    field :lastname, :string
    field :email, :string
    field :email_source, :string
    field :profile_url, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :verified_at, :utc_datetime
    field :sign_in_attempt, :integer, default: 0
    field :subscription_expired_at, :utc_datetime

    has_one :email_verification_token, Munchkin.Accounts.UserToken, where: [type: 1]
    has_many :access_tokens, Munchkin.Accounts.UserToken, where: [type: 2]
    has_many :refresh_tokens, Munchkin.Accounts.UserToken, where: [type: 3]
    has_many :forgot_password_tokens, Munchkin.Accounts.UserToken, where: [type: 4]
    has_many :two_factor_tokens, Munchkin.Accounts.UserToken, where: [type: 5]
    has_many :subcriptions_tokens, Munchkin.Accounts.UserToken, where: [type: 6]

    has_many :subscriptions, Munchkin.Subscription.Plan
    has_many :integrations, Munchkin.Accounts.Integration

    has_one :tier, through: [:subscriptions, :product]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:firstname, :lastname, :email, :password, :email_source])
    |> validate_required([:firstname, :lastname, :email, :email_source])
    |> should_mark_email_valid?()
    |> should_cast_password?()
    |> downcase_emaiL()
    |> unique_constraint(:email)
  end

  @doc false
  def login_changeset(user, attrs) do
    user
    |> cast(attrs, [])
    |> assign_values([:sign_in_attempt], increment: true, increment_by: 1)
  end

  @doc false
  def email_verified_changeset(user, attrs) do
    user
    |> cast(attrs, [])
    |> assign_values([:verified_at], default: DateTime.utc_now(:second))
  end

  defp should_mark_email_valid?(changeset) do
    case get_field(changeset, :email_source) do
      "google" -> should_change_verify(changeset)
      _ -> changeset
    end
  end

  defp should_change_verify(changeset) do
    case get_field(changeset, :verified_at) do
      nil -> assign_values(changeset, [:verified_at], default: DateTime.utc_now(:second))
      _ -> changeset
    end
  end

  defp should_cast_password?(changeset) do
    case get_field(changeset, :email_source) do
      "google" ->
        add_password_error(changeset)

      _ ->
        changeset
        |> validate_required([:password])
        |> cast_password()
    end
  end

  defp add_password_error(changeset) do
    case get_field(changeset, :password) do
      nil -> changeset
      _ -> add_error(changeset, :password, "cannot add password on OAUTH account")
    end
  end

  defp cast_password(changeset) do
    case fetch_change(changeset, :password) do
      {:ok, value} ->
        hash = Argon2.hash_pwd_salt(value)
        put_change(changeset, :password_hash, hash)

      _ ->
        changeset
    end
  end

  defp increment_value(current_value, kw) do
    case Keyword.keyword?(kw) do
      true -> Keyword.get(kw, :increment_by, current_value)
      _ -> current_value
    end
  end

  defp get_increment_value(key, current_value, keyword, opts) do
    case Keyword.get(opts, :increment, false) do
      true ->
        increment_value(current_value, keyword)

      _ ->
        case Keyword.keyword?(keyword) do
          true -> Keyword.get(keyword, key, current_value)
          _ -> current_value
        end
    end
  end

  defp assign_values(changeset, keyword, opts) do
    default = Keyword.get(opts, :default, 1)

    case Keyword.keyword?(keyword) do
      true -> Keyword.keys(keyword)
      _ -> keyword
    end
    |> Enum.reduce(changeset, fn key, acc ->
      value = get_increment_value(key, default, keyword, opts)

      case get_field(acc, key) do
        val when is_number(value) -> put_change(acc, key, value + val)
        _ -> put_change(acc, key, value)
      end
    end)
  end

  defp downcase_emaiL(changeset) do
    case get_change(changeset, :email) do
      email -> put_change(changeset, :email, String.downcase(email))
      _ -> changeset
    end
  end
end
