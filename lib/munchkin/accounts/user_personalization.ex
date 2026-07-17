defmodule Munchkin.Accounts.UserPersonalization do
  use Ecto.Schema

  import Ecto.Changeset, warn: false

  @primary_key false
  embedded_schema do
    field :theme, Ecto.Enum, values: [:dark, :light, :system]
    field :portfolio_calculation, Ecto.Enum, values: [:fifo, :lifo, :selected]
    field :default_market, :integer
    field :overview_tickers, {:array, :string}, default: []
  end

  def changeset(personalization, attrs \\ %{}) do
    personalization
    |> cast(attrs, [:theme, :portfolio_calculation, :default_market, :overview_tickers])
    |> set_default_theme()
    |> set_default_calculation()
    |> set_default_market()
    |> set_default_overview_tickers()
  end

  defp set_default_theme(changeset) do
    case get_field(changeset, :theme) do
      data when data in [:dark, :light, :system] -> changeset
      _ -> put_change(changeset, :theme, :dark)
    end
  end

  defp set_default_calculation(changeset) do
    case get_field(changeset, :portfolio_calculation) do
      data when data in [:fifo, :lifo, :selected] -> changeset
      _ -> put_change(changeset, :portfolio_calculation, :fifo)
    end
  end

  defp set_default_market(changeset) do
    default = 1000

    case get_field(changeset, :default_market) do
      data when is_number(data) -> changeset
      _ -> put_change(changeset, :default_market, default)
    end
  end

  defp set_default_overview_tickers(changeset) do
    case get_field(changeset, :overview_tickers) do
      [_ | _] ->
        changeset

      _ ->
        put_change(changeset, :overview_tickers, [
          "FOREXCOM:SPXUSD",
          "CMCMARKETS:GOLD",
          "FX_IDC:IDRUSD"
        ])
    end
  end
end
