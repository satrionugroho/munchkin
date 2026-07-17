defmodule Munchkin.Accounts.Realization do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "realizations" do
    field :related_transactions, {:array, :string}
    field :value, :decimal

    belongs_to :user, Munchkin.Accounts.User, foreign_key: :user_id, type: :integer
    belongs_to :asset, Munchkin.Inventory.Asset, foreign_key: :asset_id, type: :integer

    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = realization, attrs \\ %{}) do
    realization
    |> cast(attrs, [:related_transactions, :value, :user_id, :asset_id])
    |> validate_required([:related_transactions, :value, :user_id, :asset_id])
  end
end
