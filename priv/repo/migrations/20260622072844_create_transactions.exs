defmodule Munchkin.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  @disable_migration_lock true
  @disable_ddl_transaction true

  def change do
    create table(:transactions, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :asset_id, references(:assets, on_delete: :nothing), null: false
      add :status, :integer, default: 1
      add :transaction_type, :integer, null: false
      add :reference_id, :string
      add :transaction_date, :utc_datetime, null: false
      add :settlement_date, :utc_datetime
      add :price, :integer, null: false
      add :quantity, :integer, null: false
      add :fee, :decimal
      add :others, :map
      add :total_value, :decimal
      add :current_quantity, :integer
      add :realizations, :map

      timestamps(type: :utc_datetime)
    end
  end
end
