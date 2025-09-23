defmodule Munchkin.Repo.Migrations.CreateUserIntegrations do
  use Ecto.Migration

  def change do
    create table(:user_integrations, primary_key: false) do
      add :user_id, references(:users, on_delete: :nothing), primary_key: true
      add :idempotency_id, :string
      add :provider, :string, primary_key: true
    end
  end
end
