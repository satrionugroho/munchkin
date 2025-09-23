defmodule Munchkin.SubscriptionFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Munchkin.Subscription` context.
  """

  @doc """
  Generate a plan.
  """
  def plan_fixture(attrs \\ %{}) do
    {:ok, plan} =
      attrs
      |> Enum.into(%{
        currency: "some currency",
        idempotency_id: "7488a646-e31f-11e4-aace-600308960662"
      })
      |> Munchkin.Subscription.create_plan()

    plan
  end

  @doc """
  Generate a payment.
  """
  def payment_fixture(attrs \\ %{}) do
    {:ok, payment} =
      attrs
      |> Enum.into(%{
        amount: "120.5",
        start_from: ~D[2025-09-16],
        valid_until: ~D[2025-09-16]
      })
      |> Munchkin.Subscription.create_payment()

    payment
  end

  @doc """
  Generate a payment_detail.
  """
  def payment_detail_fixture(attrs \\ %{}) do
    {:ok, payment_detail} =
      attrs
      |> Enum.into(%{
        amount: "120.5",
        currency: "some currency",
        metadata: %{},
        type: 42
      })
      |> Munchkin.Subscription.create_payment_detail()

    payment_detail
  end

  @doc """
  Generate a product.
  """
  def product_fixture(attrs \\ %{}) do
    {:ok, product} =
      attrs
      |> Enum.into(%{
        description: "some description",
        features: "some features",
        limitations: "some limitations",
        name: "some name"
      })
      |> Munchkin.Subscription.create_product()

    product
  end
end
