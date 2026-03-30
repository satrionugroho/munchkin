defmodule Munchkin.Repo.Migrations.CreateAnalizerResults do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:analizer_results, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :user_id, references(:users, on_delete: :nothing)
      add :summary_id, :binary, null: true
      add :analizers, :map, null: false
      add :result, :map, null: true

      timestamps(type: :utc_datetime)
    end
  end
end
