defmodule Munchkin.Repo.Migrations.AddTradeData do
  use Ecto.Migration

  def change do
    alter table(:trade_histories) do
      add :ask, :decimal
      add :ask_volume, :decimal
      add :bid, :decimal
      add :bid_volume, :decimal
      add :frequency, :integer
    end
  end
end
