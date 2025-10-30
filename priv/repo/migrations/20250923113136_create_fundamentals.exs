defmodule Munchkin.Repo.Migrations.CreateFundamentals do
  use Ecto.Migration

  @disable_migration_lock true
  @disable_ddl_transaction true

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"")

    create table(:fundamentals, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")

      add :ancestor_id, references(:fundamentals, on_delete: :delete_all, type: :uuid), null: true

      add :asset_id, references(:assets, on_delete: :nothing), null: false
      add :ref_id, references(:asset_sources, on_delete: :nothing, type: :uuid), null: false
      add :period, :string, null: false
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:fundamentals, [:asset_id, :ref_id, :period], concurrently: true)

    create table(:fundamental_idx, primary_key: false) do
      add :id, references(:fundamentals, on_delete: :delete_all, type: :uuid), primary_key: true

      add :general, :map
      add :cashflow, :map
      add :balance_sheet, :map
      add :income_statement, :map
      add :metadata, :map, default: %{}
    end

    create unique_index(:fundamentals_idx, [:id], concurrently: true)
  end

  def down do
    drop table(:fundamentals_idx)
    drop table(:fundamentals)
  end
end
