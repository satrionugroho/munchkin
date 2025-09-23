defmodule Munchkin.ThirdParty.Xendit do
  @behaviour Munchkin.Integrations.Payment

  def register_user(params) do
    {:ok, params}
  end

  def subscribe(params) do
    {:ok, params}
  end

  def unsubscribe(params) do
    {:ok, params}
  end

  def compose_subscription_params(user_id, product) do
    %{
      "reference_id" => Ecto.UUID.generate(),
      "customer_id" => user_id,
      "recurring_action" => "PAYMENT",
      "currency" => Map.get(product, :currency),
      "amount" => Map.get(product, :price) |> Decimal.to_integer(),
      "schedule" => %{
        "reference_id" => Ecto.UUID.generate(),
        "interval" => "MONTH",
        "interval_count" => 1
      },
      "success_return_url" => success_url(),
      "failed_return_url" => failed_url(),
      "items" => [
        %{
          "type" => "DIGITAL_SERVICE",
          "name" => Map.get(product, :name),
          "net_unit_amount" => Map.get(product, :price) |> Decimal.to_integer(),
          "quantity" => 1
        }
      ]
    }
  end

  def compose_unsubscribe_params(_user_id, plan) do
    %{
      "id" => Map.get(plan, :id)
    }
  end

  defp success_url do
    Application.get_env(:munchkin, __MODULE__, [])
    |> Keyword.get(:success_url, "http://localhost:4000/subscription-success")
  end

  defp failed_url do
    Application.get_env(:munchkin, __MODULE__, [])
    |> Keyword.get(:failed_url, "http://localhost:4000/subscription-failed")
  end

  def name, do: "xendit"
end
