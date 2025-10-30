defmodule Munchkin.Inventory.Asset do
  use Ecto.Schema

  import Ecto.Changeset, warn: false

  schema "assets" do
    field :name, :string

    field :type_id, Munchkin.EctoType.Enum,
      values: [:stock, :bond, :mutualfund, :index],
      module: Munchkin.Inventory.AssetType

    field :address, :string
    field :email, :string
    field :issued_date, :date
    field :website, :string
    field :sector, :string
    field :subsector, :string
    field :industry, :string
    field :subindustry, :string
    field :metadata, :map, default: %{}

    has_many :tickers, Munchkin.Inventory.AssetTicker

    timestamps(type: :utc_datetime)
  end

  def changeset(asset, params \\ %{}) do
    asset
    |> cast(params, [
      :name,
      :type_id,
      :address,
      :email,
      :issued_date,
      :website,
      :sector,
      :subsector,
      :industry,
      :subindustry,
      :metadata
    ])
    |> validate_required([:name])
    |> must_downcase([:subsector, :subindustry, :industry, :sector])
  end

  defp must_downcase(changeset, []), do: changeset

  defp must_downcase(changeset, [head | tail]) do
    case get_change(changeset, head) do
      nil ->
        must_downcase(changeset, tail)

      data ->
        put_change(changeset, head, String.downcase(data))
        |> must_downcase(tail)
    end
  end
end
