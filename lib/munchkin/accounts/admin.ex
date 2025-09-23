defmodule Munchkin.Accounts.Admin do
  use Ecto.Schema
  import Ecto.Changeset

  schema "admins" do
    field :email, :string
    field :fullname, :string
    field :password, :string, virtual: true
    field :password_hash, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(admin, attrs) do
    admin
    |> cast(attrs, [:email, :fullname, :password])
    |> validate_required([:email, :fullname, :password])
    |> change_password()
  end

  defp change_password(changeset) do
    case fetch_change(changeset, :password) do
      {:ok, value} ->
        hash = Argon2.hash_pwd_salt(value)
        put_change(changeset, :password_hash, hash)

      _ ->
        changeset
    end
  end
end
