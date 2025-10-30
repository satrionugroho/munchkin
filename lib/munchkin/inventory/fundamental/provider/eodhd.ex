defmodule Munchkin.Inventory.Fundamental.Provider.EODHD do
  use Ecto.Schema

  import Ecto.Changeset, warn: false

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "fundamental_eodhd" do
    field :balance_sheet, :map
    field :cashflow, :map
    field :income_statement, :map
    field :metadata, :map
  end

  def changeset(eodhd, attrs \\ %{}) do
    eodhd
    |> cast(attrs, [:balance_sheet, :cashflow, :income_statement, :metadata])
    |> validate_required([:id])
  end

  def translate(data, :general), do: data

  def translate(data, _type) do
    data
  end
end
