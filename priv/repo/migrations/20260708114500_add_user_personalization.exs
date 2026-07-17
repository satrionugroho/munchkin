defmodule Munchkin.Repo.Migrations.AddUserPersonalization do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :personalization, :jsonb, default: "{}"
    end
  end

  def down do
    alter table(:users) do
      remove_if_exists :personalization
    end
  end
end
