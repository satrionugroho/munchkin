defmodule Munchkin.ThirdParty.XenditMock do
  @behaviour Munchkin.Integrations.Payment

  def register_user(params) do
    :timer.sleep(1000)

    {:ok,
     %{
       "id" => "cust-#{Ecto.UUID.generate()}",
       "reference_id" => Ecto.UUID.generate(),
       "type" => "INDIVIDUAL",
       "individual_detail" => params,
       "business_detail" => %{
         "business_name" => nil,
         "trading_name" => nil,
         "business_type" => nil,
         "nature_of_business" => nil,
         "business_domicile" => nil,
         "date_of_registration" => nil
       },
       "mobile_number" => nil,
       "phone_number" => nil,
       "hashed_phone_number" => nil,
       "email" => Map.get(params, "email", nil),
       "addresses" => [],
       "identity_accounts" => [],
       "kyc_documents" => [],
       "description" => nil,
       "date_of_registration" => Date.utc_today() |> Date.to_string(),
       "domicile_of_registration" => nil,
       "metadata" => {},
       "created" => DateTime.utc_now() |> DateTime.to_iso8601(),
       "updated" => DateTime.utc_now() |> DateTime.to_iso8601()
     }}
  end

  def subscribe(params) do
    required_keys = [
      "reference_id",
      "customer_id",
      "recurring_action",
      "currency",
      "amount",
      "schedule",
      "items",
      "failed_return_url",
      "success_return_url"
    ]

    required_keys_length = length(required_keys)
    taken = Map.take(params, required_keys)

    taken
    |> Map.keys()
    |> length()
    |> case do
      l when l == required_keys_length -> success_subscribe_response(taken)
      _ -> error_response("Error due to subscribe")
    end
  end

  defp success_subscribe_response(params) do
    :timer.sleep(1000)

    schedule_ref = Map.get(params, "schedule", %{})
    item_ref = Map.get(params, "items", [%{}]) |> List.first()

    {:ok,
     %{
       "reference_id" => Map.get(params, "reference_id"),
       "customer_id" => Map.get(params, "customer_id"),
       "recurring_action" => Map.get(params, "recurring_action"),
       "currency" => Map.get(params, "currency"),
       "amount" => Map.get(params, "amount") |> to_safe_integer(),
       "schedule" => %{
         "reference_id" => Map.get(schedule_ref, "reference_id"),
         "interval" => Map.get(schedule_ref, "interval"),
         "interval_count" => Map.get(schedule_ref, "interval_count")
       },
       "success_return_url" => Map.get(params, "success_return_url"),
       "failed_return_url" => Map.get(params, "failed_return_url"),
       "items" => [
         %{
           "type" => Map.get(item_ref, "type"),
           "name" => Map.get(item_ref, "name"),
           "net_unit_amount" => Map.get(item_ref, "net_unit_amount") |> to_safe_integer(),
           "quantity" => Map.get(item_ref, "quantity") |> to_safe_integer()
         }
       ],
       "id" => Ecto.UUID.generate(),
       "actions" => [
         %{
           "action" => "AUTH",
           "url_type" => "WEB",
           "url" => "https://somesite.com/auth/#{Ecto.UUID.generate()}",
           "method" => "GET"
         }
       ],
       "created" => DateTime.utc_now() |> DateTime.to_iso8601(),
       "updated" => DateTime.utc_now() |> DateTime.to_iso8601()
     }}
  end

  defp error_response(msg) do
    %{
      "error_code" => "500",
      "message" => msg
    }
  end

  def unsubscribe(params) do
    case Map.get(params, "id") do
      nil -> error_response("Error due to unsubscribe")
      _ -> unsubscribe_success_response(params)
    end
  end

  defp unsubscribe_success_response(params) do
    {:ok,
     %{
       "reference_id" => Map.get(params, "reference_id"),
       "customer_id" => Map.get(params, "customer_id"),
       "recurring_action" => Map.get(params, "recurring_action"),
       "currency" => Map.get(params, "currency")
     }}
  end

  defp to_safe_integer(num) when is_number(num), do: num

  defp to_safe_integer(str) when is_bitstring(str) do
    try do
      String.to_integer(str)
    rescue
      _ -> String.replace(str, ~r/\D/, "") |> String.to_integer()
    end
  end

  defp to_safe_integer(_), do: 0

  def name, do: "xendit"

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
end
