# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Munchkin.Repo.insert!(%Munchkin.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

defmodule MunchkinMigrator do
  def should_insert_product? do
    Munchkin.Repo.all(Munchkin.Subscription.Product)
    |> case do
      [] ->
        insert_product!()

      _ ->
        :logger.info("product already inserted")
        {:ok, 1}
    end
  end

  def insert_product! do
    Enum.map(["en", "id"], fn lang ->
      :code.priv_dir(:munchkin)
      |> Kernel.to_string()
      |> Kernel.<>("/repo/seeds/product-#{lang}.json")
      |> File.read()
      |> case do
        {:ok, file} ->
          Jason.decode!(file, keys: :atoms)
          |> Map.get(:tiers)
          |> Enum.map(&Map.put(&1, :lang, lang))

        err ->
          err
      end
    end)
    |> List.flatten()
    |> then(&Munchkin.Repo.insert_all(Munchkin.Subscription.Product, &1))
    |> case do
      {row, _} when is_number(row) ->
        :logger.info("product inserted sucessfully with #{row} rows")
        {:ok, true}

      err ->
        :logger.error("cannot insert new product")
        {:error, err}
    end
  end

  def should_insert_asset_source? do
    case Munchkin.Repo.all(Munchkin.Inventory.AssetSource) do
      [] -> insert_asset_source!()
      _ -> :logger.info("asset source was inserted")
    end
  end

  def insert_asset_source! do
    inserted = DateTime.utc_now(:second)

    [
      %{name: "Indonesian Exchange", abbr: "idx", id: Ecto.UUID.generate()},
      %{name: "EODHD", abbr: "eodhd", id: Ecto.UUID.generate()}
    ]
    |> Enum.map(&Map.merge(&1, %{inserted_at: inserted, updated_at: inserted}))
    |> then(&Munchkin.Repo.insert_all(Munchkin.Inventory.AssetSource, &1))
    |> case do
      {row, _} when is_number(row) ->
        :logger.info("asset source inserted sucessfully with #{row} rows")
        {:ok, true}

      err ->
        :logger.error("cannot insert new asset sources")
        {:error, err}
    end
  end

  def migrate() do
    Munchkin.Repo.transact(fn ->
      [should_insert_product?(), should_insert_asset_source?()]
      |> Enum.map(&elem(&1, 0))
      |> Enum.map(&Kernel.==(&1, :ok))
      |> Enum.all?()
      |> case do
        true -> {:ok, "migrate sucessfull"}
        _ -> {:error, "migrations error"}
      end
    end)
  end
end

MunchkinMigrator.migrate()
