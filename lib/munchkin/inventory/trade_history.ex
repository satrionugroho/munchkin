defmodule Munchkin.Inventory.TradeHistory do
  use Ecto.Schema

  require Decimal

  import Ecto.Changeset, warn: false

  @primary_key false
  schema "trade_histories" do
    field :open, :decimal
    field :high, :decimal
    field :low, :decimal
    field :close, :decimal
    field :volume, :decimal
    field :shares, :decimal
    field :ask, :decimal
    field :ask_volume, :decimal
    field :bid, :decimal
    field :bid_volume, :decimal
    field :frequency, :integer

    field :date, :date, primary_key: true

    belongs_to :asset, Munchkin.Inventory.Asset, primary_key: true

    belongs_to :source, Munchkin.Inventory.AssetSource,
      primary_key: true,
      foreign_key: :ref_id,
      type: Ecto.UUID
  end

  def changeset(trade, attrs \\ %{}) do
    trade
    |> cast(attrs, [
      :open,
      :high,
      :low,
      :close,
      :volume,
      :date,
      :shares,
      :ask,
      :ask_volume,
      :bid,
      :bid_volume,
      :frequency
    ])
    |> cast_frequency(attrs)
    |> Munchkin.Utils.Relations.cast_relations(
      [asset: Munchkin.Inventory.Asset, source: Munchkin.Inventory.AssetSource],
      attrs
    )
    |> validate_required([:close, :date])
  end

  def bulk_changeset(trade, attrs \\ %{}) do
    trade
    |> cast(attrs, [
      :open,
      :high,
      :low,
      :close,
      :volume,
      :date,
      :shares,
      :asset_id,
      :ref_id,
      :ask,
      :ask_volume,
      :bid,
      :bid_volume,
      :frequency
    ])
    |> validate_required([:close, :date, :asset_id])
  end

  defp cast_frequency(changeset, attrs) do
    case Map.get(attrs, "frequency") do
      num when not is_nil(num) -> put_frequency(changeset, num)
      _ -> changeset
    end
  end

  defp put_frequency(changeset, number) when is_integer(number) do
    put_change(changeset, :frequency, number)
  end

  defp put_frequency(changeset, num) when is_number(num) do
    num
    |> ceil()
    |> then(&put_frequency(changeset, &1))
  end

  defp put_frequency(changeset, num) do
    case Decimal.is_decimal(num) do
      true -> Decimal.to_integer(num) |> then(&put_frequency(changeset, &1))
      _ -> changeset
    end
  end
end
