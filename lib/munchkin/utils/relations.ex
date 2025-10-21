defmodule Munchkin.Utils.Relations do
  def cast_relations(changeset, relations, attrs) do
    params = mapper(attrs)

    Enum.reduce(relations, changeset, fn {key, value}, acc ->
      cast_relation(acc, key, value, params)
    end)
  end

  defp cast_relation(changeset, key, {module, opts}, attrs) do
    optional = Keyword.get(opts, :optional, false)

    case Ecto.Changeset.get_field(changeset, key) do
      %mod{} when mod == module -> changeset
      _ -> get_relation_within_attributes(changeset, key, module, attrs, optional)
    end
  end

  defp cast_relation(changeset, key, module, attrs) do
    case Ecto.Changeset.get_field(changeset, key) do
      %mod{} when mod == module -> changeset
      _ -> get_relation_within_attributes(changeset, key, module, attrs, false)
    end
  end

  defp get_relation_within_attributes(changeset, key, module, attrs, optional) do
    case Map.get(attrs, to_string(key)) do
      nil -> get_relation_from_attributes(changeset, key, module, attrs, optional)
      data -> Ecto.Changeset.put_change(changeset, key, data)
    end
  end

  defp get_relation_from_attributes(changeset, key, module, attrs, optional) do
    id = to_safe_atom("#{key}_id")

    case Ecto.Changeset.get_field(changeset, id) do
      nil -> get_data_from_database(changeset, key, module, attrs, optional)
      _ -> changeset
    end
  end

  defp get_data_from_database(changeset, id, module, attrs, optional) do
    Enum.find(attrs, fn {key, _value} -> to_string(key) == "#{id}_id" end)
    |> case do
      nil ->
        error_changeset(changeset, id, optional)

      {_, data} ->
        load_assoc_within_database(
          changeset,
          to_string(module),
          to_safe_atom("get_#{id}"),
          to_safe_atom(id),
          data,
          optional
        )
    end
  end

  defp load_assoc_within_database(changeset, schema, fun, key, id, optional) do
    context_module =
      String.split(schema, ".") |> Enum.slice(0, 3) |> Enum.join(".") |> to_safe_atom()

    case apply(context_module, fun, [id]) do
      {:ok, data} -> Ecto.Changeset.put_change(changeset, key, data)
      data when not is_nil(data) -> Ecto.Changeset.put_change(changeset, key, data)
      _ -> error_changeset(changeset, key, optional)
    end
  end

  defp error_changeset(changeset, key, false) do
    Ecto.Changeset.add_error(
      changeset,
      to_safe_atom(key),
      "association with value=#{key} cannot be nil"
    )
  end

  defp error_changeset(changeset, _key, _), do: changeset

  defp to_safe_atom(str) when is_bitstring(str) do
    try do
      String.to_existing_atom(str)
    rescue
      _ -> String.to_atom(str)
    end
  end

  defp to_safe_atom(atom), do: atom

  defp mapper(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      case is_struct(value) do
        true -> Map.put(acc, to_string(key), value)
        _ -> Map.put(acc, to_string(key), mapper(value))
      end
    end)
  end

  defp mapper([_f | _l] = list), do: Enum.map(list, &mapper/1)
  defp mapper(data), do: data
end
