defmodule Munchkin.Subscription.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :name, :string
    field :description, :string
    field :features, {:array, :string}
    field :limitations, {:array, :string}
    field :price, :decimal
    field :currency, :string
    field :is_popular, :boolean
    field :is_free, :boolean
    field :subtitle, :string
    field :button_text, :string
    field :key, :string
    field :lang, :string
    field :tier, :integer

    field :free, :boolean, virtual: true
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [
      :name,
      :description,
      :features,
      :limitations,
      :price,
      :currency,
      :subtitle,
      :lang,
      :key,
      :button_text,
      :is_free,
      :is_popular,
      :tier
    ])
    |> validate_required([
      :name,
      :description,
      :features,
      :limitations,
      :subtitle,
      :lang,
      :key,
      :button_text,
      :tier
    ])
  end
end
