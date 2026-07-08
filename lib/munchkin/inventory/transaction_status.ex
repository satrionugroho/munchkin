defmodule Munchkin.Inventory.TransactionStatus do
  @derive {JSON.Encoder, only: [:label]}
  defstruct [:id, :label, :key]

  def pending do
    %__MODULE__{id: 1, label: "Pending", key: :pending}
  end

  def queue do
    %__MODULE__{id: 2, label: "Queue", key: :queue}
  end

  def ongoing do
    %__MODULE__{id: 3, label: "Ongoing", key: :ongoing}
  end

  def executed do
    %__MODULE__{id: 4, label: "Executed", key: :executed}
  end

  def all do
    [pending(), queue(), ongoing(), executed()]
  end
end
