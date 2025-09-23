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
for key <- ["en", "id"] do
  :code.priv_dir(:munchkin)
  |> Kernel.to_string()
  |> Kernel.<>("/repo/seeds/product-#{key}.json")
  |> File.read()
  |> case do
    {:ok, file} ->
      Jason.decode!(file, keys: :atoms)
      |> Map.get(:tiers)
      |> Enum.map(&Map.put(&1, :lang, key))
      |> then(&Munchkin.Repo.insert_all(Munchkin.Subscription.Product, &1))

    err ->
      :logger.error("Cannot parse the file due to errors #{inspect(err)}")
  end
end
