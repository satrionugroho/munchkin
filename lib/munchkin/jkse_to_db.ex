defmodule Munchkin.JkseToDB do
  alias Munchkin.Engine.Jkse.Fundamental.{Type, Translation}

  def balance_sheet(expected), do: do_comparison(Type.balance_sheets(), expected)
  def income_statement(expected), do: do_comparison(Type.income_statements(), expected)
  def cashflow(expected), do: do_comparison(Type.cashflows(), expected)

  defp do_comparison(dictionaries, expected) do
    dict =
      case Enum.member?(dictionaries, expected) do
        true -> Translation.get(expected)
        _ -> raise ArgumentError, "Cannot find fundamental with type #{inspect(expected)}"
      end

    type = Type.t(expected)

    db_schema =
      :code.priv_dir(:munchkin)
      |> to_string()
      |> Kernel.<>("/data/#{type}.json")
      |> File.read!()
      |> Jason.decode!()

    Enum.map(db_schema, fn {key, value} ->
      {key, take_value_from_dict(expected, dict, value)}
    end)
    |> Enum.into(%{})
  end

  defp take_value_from_dict(name, dict, [_first | _last] = values) do
    Enum.reduce(values, [], fn key, acc ->
      case should_add?(name, key, dict) do
        data when not is_nil(data) -> [data | acc]
        _ -> acc
      end
    end)
  end

  defp take_value_from_dict(name, dict, val), do: take_value_from_dict(name, dict, [val])

  defp should_add?(name, key, dict) do
    case String.contains?(key, name) do
      true ->
        k = String.split(key, ":") |> List.last()

        Map.get(dict, k)
        |> returnable(k)

      _ ->
        Map.get(dict, key)
        |> returnable(key)
    end
  end

  defp returnable(nil, _key), do: nil
  defp returnable(_, key), do: key
end
