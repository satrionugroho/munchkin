defmodule Munchkin.Inventory.Fundamental do
  use Ecto.Schema

  import Ecto.Changeset, warn: false

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "fundamentals" do
    field :period, :string
    field :metadata, :map

    has_many :child, __MODULE__,
      foreign_key: :ancestor_id,
      on_delete: :delete_all,
      on_replace: :delete_if_exists

    belongs_to :parent, __MODULE__, foreign_key: :ancestor_id, type: Ecto.UUID
    belongs_to :asset, Munchkin.Inventory.Asset

    belongs_to :source, Munchkin.Inventory.AssetSource,
      foreign_key: :ref_id,
      type: Ecto.UUID

    has_many :tickers, through: [:asset, :tickers]

    timestamps(type: :utc_datetime)
  end

  def changeset(fundamental, attrs \\ %{}) do
    fundamental
    |> cast(attrs, [:period, :metadata])
    |> Munchkin.Utils.Relations.cast_relations(
      [
        asset: Munchkin.Inventory.Asset,
        source: Munchkin.Inventory.AssetSource,
        parent: {__MODULE__, [optional: true]}
      ],
      attrs
    )
    |> validate_required([:period])
  end
end
