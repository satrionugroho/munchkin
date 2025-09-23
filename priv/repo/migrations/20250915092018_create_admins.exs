defmodule Munchkin.Repo.Migrations.CreateAdmins do
  use Ecto.Migration

  def up do
    create table(:admins) do
      add :email, :string
      add :fullname, :string
      add :password_hash, :string

      timestamps(type: :utc_datetime)
    end

    execute "alter sequence admins_id_seq START 1000 RESTART 1000 MINVALUE 1000"
  end

  def down do
    drop table(:admins)
  end
end
