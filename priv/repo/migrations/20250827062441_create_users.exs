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
      add :sign_in_count, :integer
      add :sign_in_attempt, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
  end
end
