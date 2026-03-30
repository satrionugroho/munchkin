defmodule Munchkin.Repo.Migrations.CreateAnalizerSummaries do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:analizer_summaries) do
      add :params, :map, null: false
      add :results, :string, null: true
      add :hex, :binary, null: true
      add :executed_at, :naive_datetime, null: true
      add :finished_at, :naive_datetime, null: true

      timestamps(type: :utc_datetime)
    end

    execute "alter sequence analizer_summaries_id_seq START 1000 RESTART 1000 MINVALUE 1000"
    create_if_not_exists index(:analizer_summaries, [:hex])
  end
end
