defmodule Munchkin.Repo.Migrations.CreateTradeHistory do
  use Ecto.Migration

  def change do
    create table(:trade_histories, primary_key: false) do
      add :asset_id, references(:assets, on_delete: :nothing), primary_key: true
      add :ref_id, references(:asset_sources, on_delete: :nothing, type: :uuid), primary_key: true
      add :date, :date, primary_key: true
      add :open, :decimal, precision: 8, scale: 5
      add :high, :decimal, precision: 8, scale: 5
      add :low, :decimal, precision: 8, scale: 5
      add :close, :decimal, precision: 8, scale: 5
      add :volume, :decimal, precision: 10, scale: 5
    end

    create index(:trade_histories, [:asset_id, :ref_id])
  end
end
