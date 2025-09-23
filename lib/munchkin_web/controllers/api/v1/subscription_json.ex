defmodule MunchkinWeb.API.V1.SubscriptionJSON do
  def render("show.json", %{subscription: subscription}) do
    %{
      action: "subscription",
      messages: [],
      data: subscription_data(subscription)
    }
  end

  def subscription_data(%Munchkin.Subscription.Plan{product: product} = subscription) do
    subscription
    |> Map.take([:currency, :ended_at, :metadata, :id, :inserted_at])
    |> Map.merge(%{
      product_name: product.name,
      product_id: product.id,
      price: Decimal.to_integer(product.price),
      description: product.description,
      free: product.is_free,
      features: product.features,
      limitations: product.limitations,
      payments: payments_data(subscription.payments)
    })
  end

  def payments_data([]), do: []
  def payments_data(payments), do: Enum.map(payments, &payment_data/1)

  defp payment_data(payment) do
    Map.take(payment, [:valid_until, :start_from, :amount, :id])
  end
end
