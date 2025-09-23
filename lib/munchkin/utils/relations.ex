defmodule Munchkin.Utils.Relations do
  def cast_relations(changeset, relations, attrs) do
    Enum.reduce(relations, changeset, fn {key, value}, acc ->
      cast_relation(acc, key, value, attrs)
    end)
  end

  defp cast_relation(changeset, key, module, attrs) do
    case Ecto.Changeset.get_field(changeset, key) do
      %mod{} when mod == module -> changeset
      _ -> get_relation_from_attributes(changeset, key, module, attrs)
    end
  end

  defp get_relation_from_attributes(changeset, key, module, attrs) do
    id = to_safe_atom("#{key}_id")

    case Ecto.Changeset.get_field(changeset, id) do
      nil -> get_data_from_database(changeset, key, module, attrs)
      _ -> changeset
    end
  end

  defp get_data_from_database(changeset, id, module, attrs) do
    Enum.find(attrs, fn {key, _value} -> to_string(key) == "#{id}_id" end)
    |> case do
      nil ->
        error_changeset(changeset, id)

      {_, data} ->
        load_assoc_within_database(
          changeset,
          to_string(module),
          to_safe_atom("get_#{id}"),
          to_safe_atom(id),
          data
        )
    end
  end

  defp load_assoc_within_database(changeset, schema, fun, key, id) do
    context_module =
      String.split(schema, ".") |> Enum.slice(0, 3) |> Enum.join(".") |> to_safe_atom()

    case apply(context_module, fun, [id]) do
      {:ok, data} -> Ecto.Changeset.put_change(changeset, key, data)
      data when not is_nil(data) -> Ecto.Changeset.put_change(changeset, key, data)
      _ -> error_changeset(changeset, key)
    end
  end

  defp error_changeset(changeset, key) do
    Ecto.Changeset.add_error(
      changeset,
      to_safe_atom(key),
      "association with value=#{key} cannot be nil"
    )
  end

  defp to_safe_atom(str) when is_bitstring(str) do
    try do
      String.to_existing_atom(str)
    rescue
      _ -> String.to_atom(str)
    end
  end

  defp to_safe_atom(atom), do: atom
end
