defmodule Munchkin.Inventory.TransactionType do
  @derive {JSON.Encoder, only: [:label]}
  defstruct [:id, :label, :key]

  def buy do
    %__MODULE__{id: 1, label: "Buy", key: :buy}
  end

  def sell do
    %__MODULE__{id: 2, label: "Sell", key: :sell}
  end
end
