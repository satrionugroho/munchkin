defmodule Munchkin.Inventory.Fundamental.Provider.Factset do
  use Ecto.Schema

  import Ecto.Changeset, warn: false

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "fundamental_factset" do
    field :data, :map
    field :metadata, :map
  end

  def changeset(factset, attrs \\ %{}) do
    factset
    |> cast(attrs, [:data, :metadata, :id])
    |> validate_required([:id, :data])
  end

  def translate(data, :general) do
    data
  end

  def translate(data, type) do
    with {:ok, available_translations} <- Munchkin.Engine.Translation.translate(to_string(type)),
         ticker <- Map.get(data, "ticker_exchange"),
         fs_date <- Map.get(data, "date"),
         date <- Date.from_iso8601!(fs_date),
         fiscal_year <- Munchkin.Inventory.fiscal_quarter(date),
         translations <- filter_translation(available_translations),
         parsed <- parse_data(data, translations) do
      Map.put(parsed, "name", ticker)
      |> Map.put("period", "#{date.year}#{fiscal_year}")
    else
      _ -> %{}
    end
  end

  defp filter_translation(translations) do
    Enum.reduce(translations, %{}, fn
      {key, val}, acc when is_list(val) ->
        Enum.filter(val, &String.contains?(&1, "factset"))
        |> then(&Map.put(acc, key, &1))

      {key, val}, acc when is_bitstring(val) ->
        String.contains?(val, key)
        |> then(fn
          true -> Map.put(acc, key, val)
          _ -> acc
        end)
    end)
  end

  defp parse_data(data, translations) do
    Enum.reduce(translations, %{}, fn {k, item}, acc ->
      key = String.split(k, ":") |> List.last()

      get_data(data, item)
      |> then(&Map.put(acc, key, &1))
    end)
    |> calculate_calculated_keys()
  end

  defp get_data(_data, "factset:CALCULATED" <> _rest = key), do: key
  defp get_data(data, "factset:" <> key), do: get_actual_data(data, key)

  defp get_data(data, keys) do
    Enum.reduce(keys, 0, fn k, acc ->
      case get_data(data, k) do
        num when is_number(num) -> Kernel.+(num, acc)
        res -> [res | [acc]] |> :lists.flatten()
      end
    end)
  end

  defp get_actual_data(data, "CALCULATED{" <> rest) do
    rest
    |> String.split(",")
    |> Enum.map(&get_actual_data(data, &1))
  end

  defp get_actual_data(data, "-" <> key) do
    get_actual_data(data, key)
    |> Kernel.*(-1)
  end

  defp get_actual_data(data, key) when is_bitstring(key) do
    k = String.replace(key, ~r/\W/, "")

    case Map.get(data, "ff_#{k}", 0) do
      num when is_number(num) -> num
      _ -> 0
    end
  end

  defp get_actual_data(_data, _key), do: 0

  defp calculate_calculated_keys(data) do
    Enum.reduce(data, %{}, fn
      {key, val}, acc when is_number(val) ->
        Map.put(acc, key, val)

      {key, val}, acc when is_list(val) ->
        Enum.map(val, &get_actual_data(data, &1))
        |> Enum.sum()
        |> then(&Map.put(acc, key, &1))
    end)
  end
end
