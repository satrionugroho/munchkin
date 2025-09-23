defmodule Munchkin.PaymentMethod do
  def data do
    [
      %{id: 1, name: "Credit Card", key: "cc"},
      %{id: 2, name: "DANA", key: "dana"},
      %{id: 3, name: "GoPay", key: "gopay"},
      %{id: 4, name: "ShopeePay", key: "shopee"}
    ]
  end
end
