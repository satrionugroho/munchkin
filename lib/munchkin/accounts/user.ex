defmodule Munchkin.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :firstname, :string
    field :lastname, :string
    field :email, :string
    field :profile_url, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :verified_at, :naive_datetime
    field :sign_in_count, :integer, default: 0
    field :sign_in_attempt, :integer, default: 0
    field :subcription_expired_at, :naive_datetime
    field :tier, :integer, default: 0

    has_many :user_tokens, Munchkin.Accounts.UserToken

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:firstname, :lastname, :email, :password])
    |> validate_required([:firstname, :lastname, :email, :password])
    |> cast_password()
    |> unique_constraint(:email)
  end

  @doc false
  def success_login_changeset(user, attrs) do
    user
    |> cast(attrs, [])
    |> assign_values([:sign_in_count, :sign_in_attempt], increment: true, increment_by: 1)
  end

  @doc false
  def failed_login_changeset(user, attrs) do
    user
    |> cast(attrs, [])
    |> assign_values([:sign_in_attempt], increment: true, increment_by: 1)
  end

  @doc false
  def email_verified_changeset(user, attrs) do
    user
    |> cast(attrs, [])
    |> assign_values([:verified_at], default: NaiveDateTime.utc_now(:second))
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
end
