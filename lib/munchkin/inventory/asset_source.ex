defmodule Munchkin.Inventory.AssetSource do
  use Ecto.Schema

  import Ecto.Changeset, warn: false

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "asset_sources" do
    field :name, :string
    field :abbr, :string
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def changeset(asset_source, attrs \\ %{}) do
    asset_source
    |> cast(attrs, [:name, :abbr, :metadata])
    |> validate_required([:name])
  end

  def detail(abbr) do
    case abbr do
      "idx" -> Munchkin.Inventory.FundamentalIDX
      _ -> raise ArgumentError, "not implement for fundamental detail with #{inspect(abbr)}"
    end
  end
end
