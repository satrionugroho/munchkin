defmodule Munchkin.Repo.Migrations.CreateTradeHistory do
  use Ecto.Migration

  def change do
    create table(:trade_histories, primary_key: false) do
      add :asset_id, references(:assets, on_delete: :nothing), primary_key: true
      add :ref_id, references(:asset_sources, on_delete: :nothing, type: :uuid), primary_key: true
      add :date, :date, primary_key: true
      add :open, :decimal
      add :high, :decimal
      add :low, :decimal
      add :close, :decimal
      add :volume, :decimal
      add :shares, :decimal
    end

    create index(:trade_histories, [:asset_id, :ref_id])
  end
end
