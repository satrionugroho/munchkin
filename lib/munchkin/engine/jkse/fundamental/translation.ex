defmodule Munchkin.Engine.Jkse.Fundamental.Translation do
  alias Munchkin.Engine.Jkse.Fundamental.Type

  def get(type), do: Munchkin.Engine.Translation.get("idx:#{type}")

  def parse(data) do
    case Map.get(data, "version") do
      nil -> {:error, "cannot parse the given data"}
      ver -> parse_detail(ver, data)
    end
  end

  defp parse_detail(version, data) do
    fundamental_type = Type.t(version)

    case Munchkin.Engine.Translation.translate(fundamental_type) do
      {:ok, translations} ->
        parse_data(data, version, translations)

      _ ->
        :logger.warning("cannot parse fundamental with type #{inspect(version)}")
        {:ok, %{}}
    end
  end

  defp parse_data(data, version, translations) do
    Enum.reduce(translations, %{}, fn {key, translation}, acc ->
      Map.put(acc, key, get_data(data, version, translation))
    end)
    |> calculate_calculated_items()
  end

  defp get_data(data, version, translations) when is_list(translations) do
    Enum.reduce(translations, [], fn key, acc ->
      case get_data(data, version, key) do
        0 -> acc
        nil -> acc
        d -> [d | acc]
      end
    end)
    |> then(fn res ->
      case Enum.all?(res, &is_number/1) do
        true -> Enum.sum(res)
        _ -> res
      end
    end)
  end

  defp get_data(_, _version, "factset:" <> _rest), do: 0

  defp get_data(_data, version, "CALCULATED" <> rest = key) do
    case String.contains?(rest, version) do
      true -> key
      _ -> 0
    end
  end

  defp get_data(data, version, translation) do
    case Regex.match?(~r/\d/, translation) do
      true -> get_data_advanced(data, version, translation)
      _ -> Map.get(data, translation, 0)
    end
  end

  defp get_data_advanced(data, version, translation) do
    case String.contains?(translation, version) do
      true ->
        key = String.replace(translation, ~r/\d|\W/, "")
        Map.get(data, key, 0)

      _ ->
        0
    end
  end

  defp calculate_calculated_items(data) do
    Enum.reduce(data, %{}, fn
      {key, val}, acc when is_number(val) ->
        Map.put(acc, key, val)

      {key, val}, acc when is_bitstring(val) ->
        value = calculated_value(data, val)
        Map.put(acc, key, value)

      {key, val}, acc when is_list(val) ->
        value = Enum.map(val, &calculated_value(data, &1)) |> Enum.sum()
        Map.put(acc, key, value)
    end)
  end

  defp calculated_value(data, "CALCULATED{" <> rest) do
    String.split(rest, "}")
    |> List.first()
    |> String.split(",")
    |> Enum.reduce(0, fn key, acc ->
      mul =
        case String.contains?(key, "-") do
          true -> -1
          _ -> 1
        end

      case Map.get(data, key, 0) do
        nil -> acc
        val when is_number(val) -> acc + val * mul
        val when is_bitstring(val) -> acc + calculated_value(data, val)
      end
    end)
  end

  defp calculated_value(data, _key) do
    data
  end
end
