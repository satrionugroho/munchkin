defmodule Munchkin.Subscription.Payment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "subscription_payments" do
    field :valid_until, :date
    field :start_from, :date
    field :amount, :decimal

    belongs_to :plan, Munchkin.Subscription.Plan, type: Ecto.UUID
    has_many :details, Munchkin.Subscription.PaymentDetail, foreign_key: :payment_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [:valid_until, :start_from, :amount])
    |> validate_required([:valid_until, :start_from, :amount])
  end
end
