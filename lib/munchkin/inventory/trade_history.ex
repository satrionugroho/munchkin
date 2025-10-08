defmodule Munchkin.Inventory.TradeHistory do
  use Ecto.Schema

  import Ecto.Changeset, warn: false

  @primary_key false
  schema "trade_histories" do
    field :open, :decimal
    field :high, :decimal
    field :low, :decimal
    field :close, :decimal
    field :volume, :decimal

    field :date, :date, primary_key: true

    belongs_to :asset, Munchkin.Inventory.Asset, primary_key: true

    belongs_to :source, Munchkin.Inventory.AssetSource,
      primary_key: true,
      foreign_key: :ref_id,
      type: Ecto.UUID
  end

  def changeset(trade, attrs \\ %{}) do
    trade
    |> cast(attrs, [:open, :high, :low, :close, :volume, :date])
    |> Munchkin.Utils.Relations.cast_relations(
      [asset: Munchkin.Inventory.Asset, source: Munchkin.Inventory.AssetSource],
      attrs
    )
    |> validate_required([:close, :date])
  end
end
