defmodule Munchkin.Inventory.FundamentalIDX do
  alias Munchkin.Engine.Jkse.Fundamental.Translation
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

  def translate(data, :general) do
    data
  end

  def translate(data, _) do
    Translation.parse(data)
  end
end
