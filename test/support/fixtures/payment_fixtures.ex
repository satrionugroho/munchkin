defmodule Munchkin.PaymentFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Munchkin.Payment` context.
  """

  @doc """
  Generate a unique subscription idempotency_id.
  """
  def unique_subscription_idempotency_id do
    raise "implement the logic to generate a unique subscription idempotency_id"
  end

  @doc """
  Generate a subscription.
  """
  def subscription_fixture(attrs \\ %{}) do
    {:ok, subscription} =
      attrs
      |> Enum.into(%{
        amount: "120.5",
        idempotency_id: unique_subscription_idempotency_id(),
        payment_method: 42
      })
      |> Munchkin.Payment.create_subscription()

    subscription
  end
end
