defmodule Munchkin.Inventory.AssetTicker do
  use Ecto.Schema

  import Ecto.Changeset, warn: false

  @primary_key false
  schema "asset_tickers" do
    field :ticker, :string
    field :exchange, :string

    belongs_to :asset, Munchkin.Inventory.Asset, primary_key: true

    belongs_to :source, Munchkin.Inventory.AssetSource,
      primary_key: true,
      foreign_key: :ref_id,
      type: Ecto.UUID
  end

  def changeset(ticker, attrs \\ %{}) do
    ticker
    |> cast(attrs, [:exchange, :ticker])
    |> Munchkin.Utils.Relations.cast_relations(
      [
        asset: Munchkin.Inventory.Asset,
        source: Munchkin.Inventory.AssetSource
      ],
      attrs
    )
  end
end
