defmodule Munchkin.EctoType.Enum do
  use Ecto.ParameterizedType

  @impl true
  def type(_), do: :integer

  @impl true
  def init(opts) do
    values = Keyword.get(opts, :values)
    mod = Keyword.get(opts, :module)

    if is_nil(mod) do
      raise ArgumentError, """
        Munchkin.EctoType.Enum must give the module parameter, or use Ecto.Enum instead
      """
    end

    _ = validate_module!(mod, values)
    _ = validate_unique!(mod, values)

    mappings = Enum.map(values, &apply(mod, &1, []))

    %{
      mappings: mappings,
      module: mod
    }
  end

  defp validate_unique!(mod, values) do
    l = length(values)

    if length(Enum.uniq(values)) != l do
      raise ArgumentError, """
      Munchkin.EctoType.Enum type values must be unique.
      """
    end

    Enum.map(values, fn fun ->
      apply(mod, fun, [])
      |> Map.get(:id)
    end)
    |> Enum.uniq()
    |> length()
    |> Kernel.==(l)
    |> case do
      true ->
        :ok

      _ ->
        raise ArgumentError, """
        Munchkin.EctoType.Enum type id of given values must be unique.
        """
    end
  end

  defp validate_module!(mod, values) do
    {:module, _} = Code.ensure_compiled(mod)

    Enum.map(values, &function_exported?(mod, &1, 0))
    |> Enum.all?()
    |> case do
      false ->
        raise ArgumentError, """
        Munchkin.EctoType.Enum type values must be have function on given module.
        """

      _ ->
        :ok
    end
  end

  @impl true
  def cast(nil, _params), do: {:ok, nil}

  def cast(data, %{mappings: values, module: mod}) do
    case find_value(values, mod, data) do
      {:ok, _} = ret -> ret
      err -> err
    end
  end

  @impl true
  def load(nil, _, _), do: {:ok, nil}

  def load(data, _loader, %{mappings: values, module: mod}) do
    case find_value(values, mod, data) do
      {:ok, _} = ret -> ret
      err -> err
    end
  end

  @impl true
  def dump(nil, _, _), do: {:ok, nil}

  def dump(data, _dumper, %{mappings: values, module: mod}) do
    case find_value(values, mod, data) do
      {:ok, d} -> {:ok, Map.get(d, :id)}
      err -> err
    end
  end

  @impl true
  def equal?(a, b, _params) when is_nil(a) or is_nil(b), do: false

  def equal?(a, b, %{mappings: values, module: mod}) do
    [a, b]
    |> Enum.map(&find_value(values, mod, &1))
    |> Enum.map(&Map.get(elem(&1, 1), :id))
    |> case do
      [] -> false
      [a, b] -> a == b
    end
  end

  @impl true
  def format(%{mappings: mappings}) do
    "#Munchkin.EctoType.Enum<values: #{inspect(Keyword.keys(mappings))}>"
  end

  @impl true
  def embed_as(_, _params), do: :values

  defp find_value(_values, _module, desired) when is_nil(desired), do: {:ok, nil}

  defp find_value(values, _module, desired) when is_number(desired) do
    Enum.find(values, fn %{id: id} ->
      id == desired
    end)
    |> case do
      nil -> {:error, "cannot find entry with id=#{inspect(desired)}"}
      d -> {:ok, d}
    end
  end

  defp find_value(values, _module, desired) when is_atom(desired) or is_bitstring(desired) do
    Enum.find(values, fn %{key: key} ->
      String.equivalent?(to_string(key), to_string(desired))
    end)
    |> case do
      nil -> {:error, "cannot find entry with key=#{inspect(desired)}"}
      d -> {:ok, d}
    end
  end

  defp find_value(values, module, %mod{} = desired) when module == mod do
    Enum.find(values, &Kernel.==(&1.id, desired.id))
    |> case do
      nil -> {:error, "cannot find entry with value=#{inspect(desired)}"}
      d -> {:ok, d}
    end
  end

  defp find_value(_values, _module, desired),
    do: {:error, "cannot find entry with value #{inspect(desired)}"}
end
