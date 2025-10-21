defmodule Munchkin.Repo.Migrations.CreateUserTokens do
  use Ecto.Migration

  @disable_migration_lock true
  @disable_ddl_transaction true

  def change do
    create table(:user_tokens) do
      add :token, :binary
      add :valid_until, :utc_datetime
      add :used_at, :utc_datetime
      add :type, :integer
      add :user_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:user_tokens, [:user_id], concurrently: true)
  end
end
