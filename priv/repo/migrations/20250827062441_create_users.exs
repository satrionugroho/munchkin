defmodule Munchkin.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  @disable_migration_lock true
  @disable_ddl_transaction true

  def up do
    create table(:users) do
      add :firstname, :string
      add :lastname, :string
      add :profile_url, :string
      add :email, :string
      add :email_source, :string
      add :password_hash, :string
      add :verified_at, :utc_datetime
      add :sign_in_attempt, :integer
      add :subscription_expired_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email], concurrently: true)
    execute "alter sequence users_id_seq START 1000 RESTART 1000 MINVALUE 1000"
  end

  def down do
    drop unique_index(:users, [:email])
    drop table(:users)
  end
end
