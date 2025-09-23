defmodule Munchkin.SubscriptionTest do
  use Munchkin.DataCase

  alias Munchkin.Subscription

  describe "subscriptions" do
    alias Munchkin.Subscription.Plan

    import Munchkin.SubscriptionFixtures

    @invalid_attrs %{currency: nil, idempotency_id: nil}

    test "list_subscriptions/0 returns all subscriptions" do
      plan = plan_fixture()
      assert Subscription.list_subscriptions() == [plan]
    end

    test "get_plan!/1 returns the plan with given id" do
      plan = plan_fixture()
      assert Subscription.get_plan!(plan.id) == plan
    end

    test "create_plan/1 with valid data creates a plan" do
      valid_attrs = %{currency: "some currency", idempotency_id: "7488a646-e31f-11e4-aace-600308960662"}

      assert {:ok, %Plan{} = plan} = Subscription.create_plan(valid_attrs)
      assert plan.currency == "some currency"
      assert plan.idempotency_id == "7488a646-e31f-11e4-aace-600308960662"
    end

    test "create_plan/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Subscription.create_plan(@invalid_attrs)
    end

    test "update_plan/2 with valid data updates the plan" do
      plan = plan_fixture()
      update_attrs = %{currency: "some updated currency", idempotency_id: "7488a646-e31f-11e4-aace-600308960668"}

      assert {:ok, %Plan{} = plan} = Subscription.update_plan(plan, update_attrs)
      assert plan.currency == "some updated currency"
      assert plan.idempotency_id == "7488a646-e31f-11e4-aace-600308960668"
    end

    test "update_plan/2 with invalid data returns error changeset" do
      plan = plan_fixture()
      assert {:error, %Ecto.Changeset{}} = Subscription.update_plan(plan, @invalid_attrs)
      assert plan == Subscription.get_plan!(plan.id)
    end

    test "delete_plan/1 deletes the plan" do
      plan = plan_fixture()
      assert {:ok, %Plan{}} = Subscription.delete_plan(plan)
      assert_raise Ecto.NoResultsError, fn -> Subscription.get_plan!(plan.id) end
    end

    test "change_plan/1 returns a plan changeset" do
      plan = plan_fixture()
      assert %Ecto.Changeset{} = Subscription.change_plan(plan)
    end
  end

  describe "subscription_payments" do
    alias Munchkin.Subscription.Payment

    import Munchkin.SubscriptionFixtures

    @invalid_attrs %{valid_until: nil, start_from: nil, amount: nil}

    test "list_subscription_payments/0 returns all subscription_payments" do
      payment = payment_fixture()
      assert Subscription.list_subscription_payments() == [payment]
    end

    test "get_payment!/1 returns the payment with given id" do
      payment = payment_fixture()
      assert Subscription.get_payment!(payment.id) == payment
    end

    test "create_payment/1 with valid data creates a payment" do
      valid_attrs = %{valid_until: ~D[2025-09-16], start_from: ~D[2025-09-16], amount: "120.5"}

      assert {:ok, %Payment{} = payment} = Subscription.create_payment(valid_attrs)
      assert payment.valid_until == ~D[2025-09-16]
      assert payment.start_from == ~D[2025-09-16]
      assert payment.amount == Decimal.new("120.5")
    end

    test "create_payment/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Subscription.create_payment(@invalid_attrs)
    end

    test "update_payment/2 with valid data updates the payment" do
      payment = payment_fixture()
      update_attrs = %{valid_until: ~D[2025-09-17], start_from: ~D[2025-09-17], amount: "456.7"}

      assert {:ok, %Payment{} = payment} = Subscription.update_payment(payment, update_attrs)
      assert payment.valid_until == ~D[2025-09-17]
      assert payment.start_from == ~D[2025-09-17]
      assert payment.amount == Decimal.new("456.7")
    end

    test "update_payment/2 with invalid data returns error changeset" do
      payment = payment_fixture()
      assert {:error, %Ecto.Changeset{}} = Subscription.update_payment(payment, @invalid_attrs)
      assert payment == Subscription.get_payment!(payment.id)
    end

    test "delete_payment/1 deletes the payment" do
      payment = payment_fixture()
      assert {:ok, %Payment{}} = Subscription.delete_payment(payment)
      assert_raise Ecto.NoResultsError, fn -> Subscription.get_payment!(payment.id) end
    end

    test "change_payment/1 returns a payment changeset" do
      payment = payment_fixture()
      assert %Ecto.Changeset{} = Subscription.change_payment(payment)
    end
  end

  describe "payment_details" do
    alias Munchkin.Subscription.PaymentDetail

    import Munchkin.SubscriptionFixtures

    @invalid_attrs %{type: nil, metadata: nil, currency: nil, amount: nil}

    test "list_payment_details/0 returns all payment_details" do
      payment_detail = payment_detail_fixture()
      assert Subscription.list_payment_details() == [payment_detail]
    end

    test "get_payment_detail!/1 returns the payment_detail with given id" do
      payment_detail = payment_detail_fixture()
      assert Subscription.get_payment_detail!(payment_detail.id) == payment_detail
    end

    test "create_payment_detail/1 with valid data creates a payment_detail" do
      valid_attrs = %{type: 42, metadata: %{}, currency: "some currency", amount: "120.5"}

      assert {:ok, %PaymentDetail{} = payment_detail} = Subscription.create_payment_detail(valid_attrs)
      assert payment_detail.type == 42
      assert payment_detail.metadata == %{}
      assert payment_detail.currency == "some currency"
      assert payment_detail.amount == Decimal.new("120.5")
    end

    test "create_payment_detail/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Subscription.create_payment_detail(@invalid_attrs)
    end

    test "update_payment_detail/2 with valid data updates the payment_detail" do
      payment_detail = payment_detail_fixture()
      update_attrs = %{type: 43, metadata: %{}, currency: "some updated currency", amount: "456.7"}

      assert {:ok, %PaymentDetail{} = payment_detail} = Subscription.update_payment_detail(payment_detail, update_attrs)
      assert payment_detail.type == 43
      assert payment_detail.metadata == %{}
      assert payment_detail.currency == "some updated currency"
      assert payment_detail.amount == Decimal.new("456.7")
    end

    test "update_payment_detail/2 with invalid data returns error changeset" do
      payment_detail = payment_detail_fixture()
      assert {:error, %Ecto.Changeset{}} = Subscription.update_payment_detail(payment_detail, @invalid_attrs)
      assert payment_detail == Subscription.get_payment_detail!(payment_detail.id)
    end

    test "delete_payment_detail/1 deletes the payment_detail" do
      payment_detail = payment_detail_fixture()
      assert {:ok, %PaymentDetail{}} = Subscription.delete_payment_detail(payment_detail)
      assert_raise Ecto.NoResultsError, fn -> Subscription.get_payment_detail!(payment_detail.id) end
    end

    test "change_payment_detail/1 returns a payment_detail changeset" do
      payment_detail = payment_detail_fixture()
      assert %Ecto.Changeset{} = Subscription.change_payment_detail(payment_detail)
    end
  end

  describe "products" do
    alias Munchkin.Subscription.Product

    import Munchkin.SubscriptionFixtures

    @invalid_attrs %{name: nil, description: nil, features: nil, limitations: nil}

    test "list_products/0 returns all products" do
      product = product_fixture()
      assert Subscription.list_products() == [product]
    end

    test "get_product!/1 returns the product with given id" do
      product = product_fixture()
      assert Subscription.get_product!(product.id) == product
    end

    test "create_product/1 with valid data creates a product" do
      valid_attrs = %{name: "some name", description: "some description", features: "some features", limitations: "some limitations"}

      assert {:ok, %Product{} = product} = Subscription.create_product(valid_attrs)
      assert product.name == "some name"
      assert product.description == "some description"
      assert product.features == "some features"
      assert product.limitations == "some limitations"
    end

    test "create_product/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Subscription.create_product(@invalid_attrs)
    end

    test "update_product/2 with valid data updates the product" do
      product = product_fixture()
      update_attrs = %{name: "some updated name", description: "some updated description", features: "some updated features", limitations: "some updated limitations"}

      assert {:ok, %Product{} = product} = Subscription.update_product(product, update_attrs)
      assert product.name == "some updated name"
      assert product.description == "some updated description"
      assert product.features == "some updated features"
      assert product.limitations == "some updated limitations"
    end

    test "update_product/2 with invalid data returns error changeset" do
      product = product_fixture()
      assert {:error, %Ecto.Changeset{}} = Subscription.update_product(product, @invalid_attrs)
      assert product == Subscription.get_product!(product.id)
    end

    test "delete_product/1 deletes the product" do
      product = product_fixture()
      assert {:ok, %Product{}} = Subscription.delete_product(product)
      assert_raise Ecto.NoResultsError, fn -> Subscription.get_product!(product.id) end
    end

    test "change_product/1 returns a product changeset" do
      product = product_fixture()
      assert %Ecto.Changeset{} = Subscription.change_product(product)
    end
  end
end
