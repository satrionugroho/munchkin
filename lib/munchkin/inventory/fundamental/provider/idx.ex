defmodule Munchkin.Inventory.Fundamental.Provider.IDX do
  alias Munchkin.Engine.Jkse.Fundamental.Translation
  use Ecto.Schema

  import Ecto.Changeset, warn: false

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "fundamental_idx" do
    field :general, :map
    field :balance_sheet, :map
    field :cashflow, :map
    field :income_statement, :map
    field :metadata, :map
  end

  def changeset(idx, attrs \\ %{}) do
    idx
    |> cast(attrs, [
      :general,
      :balance_sheet,
      :cashflow,
      :income_statement,
      :metadata,
      :id
    ])
    |> validate_required([:id])
  end

  def translate(data, :general) do
    Enum.reduce(data, %{}, fn
      {key, val}, acc when is_bitstring(val) ->
        case String.contains?(val, "/") do
          true ->
            new_value = String.split(val, "/") |> List.last() |> String.trim()
            Map.put(acc, key, new_value)

          _ ->
            Map.put(acc, key, val)
        end

      {key, val}, acc ->
        Map.put(acc, key, val)
    end)
  end

  def translate(data, _) do
    Translation.parse(data)
  end
end
