defmodule Munchkin.Inventory.AssetType do
  defstruct [:id, :label, :key]

  def stock do
    %__MODULE__{id: 1, label: "Stock", key: :stock}
  end

  def mutualfund do
    %__MODULE__{id: 2, label: "Mutual Fund", key: :mutualfund}
  end

  def bond do
    %__MODULE__{id: 3, label: "Bond", key: :bond}
  end

  def index do
    %__MODULE__{id: 4, label: "Index", key: :index}
  end
end
