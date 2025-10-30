defmodule Munchkin.Repo.Migrations.CreateFactsetEodhdProdiver do
  use Ecto.Migration

  def change do
    create table(:fundamental_factset, primary_key: false) do
      add :id, references(:fundamentals, on_delete: :delete_all, type: :uuid), primary_key: true
      add :data, :map
      add :metadata, :map
    end

    create table(:fundamental_eodhd, primary_key: false) do
      add :id, references(:fundamentals, on_delete: :delete_all, type: :uuid), primary_key: true
      add :cashflow, :map
      add :balance_sheet, :map
      add :income_statement, :map
      add :metadata, :map
    end
  end
end
