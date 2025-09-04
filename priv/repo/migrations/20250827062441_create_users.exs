defmodule Munchkin.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :firstname, :string
      add :lastname, :string
      add :profile_url, :string
      add :email, :string
      add :password_hash, :string
      add :verified_at, :utc_datetime
      add :sign_in_attempt, :integer
      add :subscription_expired_at, :utc_datetime
      add :tier, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
  end
end
