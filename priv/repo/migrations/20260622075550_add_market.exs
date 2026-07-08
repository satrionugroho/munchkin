defmodule Munchkin.Repo.Migrations.AddMarket do
  use Ecto.Migration

  @disable_migration_lock true
  @disable_ddl_transaction true

  def up do
    create table(:markets) do
      add :name, :string, null: false
      add :details, :jsonb, default: "{}"

      add :fee_compositions, :jsonb, null: false

      timestamps(type: :utc_datetime)
    end

    alter table(:asset_tickers) do
      add :market_id, references(:markets, on_delete: :nothing), null: true
    end

    execute "alter sequence markets_id_seq START 1000 RESTART 1000 MINVALUE 1000"
  end

  def down do
    alter table(:asset_tickers) do
      remove :market_id
    end

    drop table(:markets)
  end
end
