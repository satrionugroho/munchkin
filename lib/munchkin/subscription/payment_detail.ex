defmodule Munchkin.Subscription.PaymentDetail do
  use Ecto.Schema
  import Ecto.Changeset

  schema "payment_details" do
    field :type, :integer
    field :amount, :decimal
    field :currency, :string
    field :metadata, :map

    belongs_to :payment, Munchkin.Subscription.Payment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(payment_detail, attrs) do
    payment_detail
    |> cast(attrs, [:type, :amount, :currency, :metadata])
    |> validate_required([:type, :amount, :currency])
  end
end
