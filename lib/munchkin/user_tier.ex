defmodule Munchkin.UserTier do
  def translate(tier) do
    Enum.find(data(), fn d ->
      Map.get(d, :tier) == tier
    end)
  end

  def data do
    [
      %{tier: 0, name: "Free", key: :free},
      %{tier: 1, name: "Basic", key: :basic},
      %{tier: 2, name: "Professional", key: :professional},
      %{tier: 3, name: "Institutional", key: :institutional}
    ]
  end
end
