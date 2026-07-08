defmodule Munchkin.Inventory.Market do
  use Ecto.Schema

  import Ecto.Changeset, warn: false

  schema "markets" do
    field :name, :string
    field :details, :map

    embeds_one :fee_compositions, Composition do
      field :buy_fee, :integer
      field :sell_fee, :integer
      field :other_fee, :map
      field :income_tax, :integer
    end

    timestamps(type: :utc_datetime)
  end

  def changeset(market, params \\ %{}) do
    market
    |> cast(params, [:name, :details])
    |> validate_required([:name])
    |> cast_embed(:fee_compositions, required: true, with: &fee_changeset/2)
  end

  def fee_changeset(fee, attrs \\ %{}) do
    fee
    |> cast(attrs, [:buy_fee, :sell_fee, :other_fee, :income_tax])
    |> validate_required([:buy_fee, :sell_fee, :other_fee, :income_tax])
  end
end
