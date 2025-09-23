defmodule Munchkin.PaymentTest do
  use Munchkin.DataCase

  alias Munchkin.Payment

  describe "subscriptions" do
    alias Munchkin.Payment.Subscription

    import Munchkin.PaymentFixtures

    @invalid_attrs %{idempotency_id: nil, amount: nil, payment_method: nil}

    test "list_subscriptions/0 returns all subscriptions" do
      subscription = subscription_fixture()
      assert Payment.list_subscriptions() == [subscription]
    end

    test "get_subscription!/1 returns the subscription with given id" do
      subscription = subscription_fixture()
      assert Payment.get_subscription!(subscription.id) == subscription
    end

    test "create_subscription/1 with valid data creates a subscription" do
      valid_attrs = %{idempotency_id: "7488a646-e31f-11e4-aace-600308960662", amount: "120.5", payment_method: 42}

      assert {:ok, %Subscription{} = subscription} = Payment.create_subscription(valid_attrs)
      assert subscription.idempotency_id == "7488a646-e31f-11e4-aace-600308960662"
      assert subscription.amount == Decimal.new("120.5")
      assert subscription.payment_method == 42
    end

    test "create_subscription/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Payment.create_subscription(@invalid_attrs)
    end

    test "update_subscription/2 with valid data updates the subscription" do
      subscription = subscription_fixture()
      update_attrs = %{idempotency_id: "7488a646-e31f-11e4-aace-600308960668", amount: "456.7", payment_method: 43}

      assert {:ok, %Subscription{} = subscription} = Payment.update_subscription(subscription, update_attrs)
      assert subscription.idempotency_id == "7488a646-e31f-11e4-aace-600308960668"
      assert subscription.amount == Decimal.new("456.7")
      assert subscription.payment_method == 43
    end

    test "update_subscription/2 with invalid data returns error changeset" do
      subscription = subscription_fixture()
      assert {:error, %Ecto.Changeset{}} = Payment.update_subscription(subscription, @invalid_attrs)
      assert subscription == Payment.get_subscription!(subscription.id)
    end

    test "delete_subscription/1 deletes the subscription" do
      subscription = subscription_fixture()
      assert {:ok, %Subscription{}} = Payment.delete_subscription(subscription)
      assert_raise Ecto.NoResultsError, fn -> Payment.get_subscription!(subscription.id) end
    end

    test "change_subscription/1 returns a subscription changeset" do
      subscription = subscription_fixture()
      assert %Ecto.Changeset{} = Payment.change_subscription(subscription)
    end
  end
end
