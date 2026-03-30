defmodule Munchkin.Inventory.Summary do
  use Ecto.Schema

  import Ecto.Changeset, warn: false

  schema "analizer_summaries" do
    field :params, :map
    field :results, :string
    field :hex, :binary

    field :executed_at, :naive_datetime
    field :finished_at, :naive_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(summary, attrs \\ %{}) do
    summary
    |> cast(attrs, [:params])
    |> validate_required([:params])
    |> then(fn s ->
      get_field(s, :params)
      |> Jason.encode!()
      |> then(&:crypto.hash(:sha256, &1))
      |> then(&put_change(s, :hex, &1))
    end)
    |> validate_required([:hex])
  end
end
