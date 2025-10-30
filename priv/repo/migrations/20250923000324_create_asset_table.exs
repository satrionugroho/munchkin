defmodule Munchkin.Repo.Migrations.CreateAssetTable do
  use Ecto.Migration

  def up do
    create table(:assets) do
      add :name, :string, null: false
      add :type_id, :integer, null: false
      add :address, :string
      add :email, :string
      add :issued_date, :date
      add :website, :string
      add :sector, :string
      add :subsector, :string
      add :industry, :string
      add :subindustry, :string
      add :metadata, :jsonb, default: "{}"

      timestamps(type: :utc_datetime)
    end

    create table(:asset_sources, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string
      add :abbr, :string
      add :priority, :integer
      add :metadata, :jsonb, default: "{}"

      timestamps(type: :utc_datetime)
    end

    create table(:asset_tickers, primary_key: false) do
      add :asset_id, references(:assets, on_delete: :nothing), primary_key: true
      add :ref_id, references(:asset_sources, on_delete: :nothing, type: :uuid), primary_key: true
      add :exchange, :string, null: false
      add :region, :string
      add :ticker, :string
    end

    create unique_index(:asset_tickers, [:ref_id, :ticker])
    create index(:asset_tickers, [:exchange, :ticker])

    execute "alter sequence assets_id_seq START 1000 RESTART 1000 MINVALUE 1000"
  end

  def down do
    drop table(:asset_tickers)
    drop table(:asset_sources)
    drop table(:assets)
  end
end
