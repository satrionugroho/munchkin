defmodule Munchkin.Repo.Migrations.CreateRealizationsTable do
  use Ecto.Migration

  def change do
    create table(:realizations, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :asset_id, references(:assets, on_delete: :nothing), null: false
      add :related_transactions, :map, null: false
      add :value, :decimal, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
