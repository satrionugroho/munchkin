defmodule Munchkin.Inventory.FundamentalIDX do
  use Ecto.Schema

  import Ecto.Changeset, warn: false

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "fundamentals_idx" do
    field :general, :map
    field :balance_sheet, :map
    field :cashflow, :map
    field :income_statement, :map
    field :metadata, :map
  end

  def changeset(idx, attrs \\ %{}) do
    idx
    |> cast(attrs, [
      :general,
      :balance_sheet,
      :cashflow,
      :income_statement,
      :metadata,
      :id
    ])
    |> validate_required([:id])
  end
end
