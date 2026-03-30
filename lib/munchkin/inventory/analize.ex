defmodule Munchkin.Inventory.Analize do
  use Ecto.Schema

  import Ecto.Changeset, warn: false

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "analizer_results" do
    field :analizers, :map
    field :result, :map
    field :summary_id, :binary

    belongs_to :user, Munchkin.Accounts.User, foreign_key: :user_id, type: :integer

    timestamps(type: :utc_datetime)
  end

  def changeset(summary, attrs \\ %{}) do
    summary
    |> cast(attrs, [:analizers, :result])
    |> validate_required(:analizers)
    |> Munchkin.Utils.Relations.cast_relations(
      [
        user: Munchkin.Accounts.User
      ],
      attrs
    )
  end
end
