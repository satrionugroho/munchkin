defmodule Munchkin.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products) do
      add :name, :string
      add :subtitle, :string
      add :description, :text
      add :features, {:array, :string}
      add :limitations, {:array, :string}
      add :price, :decimal
      add :currency, :string
      add :button_text, :string
      add :is_popular, :boolean, default: false
      add :is_free, :boolean, default: false
      add :key, :string
      add :lang, :string
      add :tier, :integer
    end

    create unique_index(:products, [:key, :lang])
  end
end
