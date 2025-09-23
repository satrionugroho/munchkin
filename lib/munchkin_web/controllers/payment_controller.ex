defmodule MunchkinWeb.PaymentController do
  use MunchkinWeb, :controller

  def show(conn, %{"id" => id, "user_id" => uid}) do
    user_id = safe_to_integer(uid)

    case Munchkin.Subscription.get_plan(id) do
      %Munchkin.Subscription.Plan{user_id: id} = subscription when id == user_id ->
        IO.inspect(subscription)
        render(conn, :show, subscription: subscription)

      _err ->
        render(conn, :error, messages: [gettext("cannot get the payment data")])
    end
  end

  defp safe_to_integer(uid) do
    try do
      String.to_integer(uid)
    rescue
      _ -> 0
    end
  end
end
