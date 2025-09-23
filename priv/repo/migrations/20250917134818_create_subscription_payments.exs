defmodule Munchkin.Repo.Migrations.CreateSubscriptionPayments do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""

    create table(:subscription_payments, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :start_from, :date
      add :plan_id, references(:subscriptions, on_delete: :nothing, type: :uuid)

      add :valid_until, :date
      add :amount, :decimal

      timestamps(type: :utc_datetime)
    end

    create index(:subscription_payments, [:plan_id])
  end

  def down do
    drop index(:subscription_payments, [:plan_id])
    drop table(:subscription_payments)
  end
end
