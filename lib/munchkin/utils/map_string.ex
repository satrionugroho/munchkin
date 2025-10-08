defmodule Munchkin.Utils.MapString do
  def perform(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      case is_struct(value) do
        true -> Map.put(acc, to_string(key), value)
        _ -> Map.put(acc, to_string(key), perform(value))
      end
    end)
  end

  def perform(list) when is_list(list), do: Enum.map(list, &perform/1)

  def perform(data), do: data
end
