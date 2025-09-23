defmodule Munchkin.Repo.Migrations.CreatePaymentDetails do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""

    create table(:payment_details, primary_key: false) do
      add :type, :integer
      add :amount, :decimal
      add :currency, :string
      add :metadata, :map
      add :payment_id, references(:subscription_payments, on_delete: :nothing, type: :uuid)

      timestamps(type: :utc_datetime)
    end

    create index(:payment_details, [:payment_id])
  end

  def down do
    drop index(:payment_details, [:payment_id])
    drop table(:payment_details)
  end
end
