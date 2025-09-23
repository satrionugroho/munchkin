defmodule Munchkin.Subscription.Plan do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "subscriptions" do
    field :idempotency_id, Ecto.UUID
    field :currency, :string
    field :ended_at, :utc_datetime
    field :metadata, :map
    field :tier, :integer

    belongs_to :user, Munchkin.Accounts.User

    belongs_to :product, Munchkin.Subscription.Product,
      define_field: false,
      foreign_key: :tier,
      references: :tier

    has_many :payments, Munchkin.Subscription.Payment, foreign_key: :plan_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(plan, attrs) do
    plan
    |> cast(attrs, [:ended_at, :idempotency_id, :metadata, :tier])
    |> Munchkin.Utils.Relations.cast_relations([user: Munchkin.Accounts.User], attrs)
    |> default()
    |> validate_required([:tier])
  end

  defp default(changeset) do
    case get_field(changeset, :idempotency_id) do
      nil -> put_change(changeset, :idempotency_id, Ecto.UUID.generate())
      _ -> changeset
    end
    |> then(fn ch ->
      case get_field(ch, :currency) do
        nil -> put_currency(ch)
        _ -> ch
      end
    end)
  end

  defp put_currency(changeset) do
    case get_field(changeset, :product) do
      %Munchkin.Subscription.Product{} = p -> put_change(changeset, :currency, p.currency)
      _ -> changeset
    end
  end
end
