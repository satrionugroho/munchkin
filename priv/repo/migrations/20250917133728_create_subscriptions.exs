defmodule Munchkin.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""

    create table(:subscriptions, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :idempotency_id, :uuid
      add :currency, :string
      add :ended_at, :utc_datetime
      add :metadata, :map
      add :user_id, references(:users, on_delete: :nothing)
      add :tier, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:subscriptions, [:user_id])
  end

  def down do
    drop index(:subscriptions, [:user_id])
    drop table(:subscriptions)
  end
end
