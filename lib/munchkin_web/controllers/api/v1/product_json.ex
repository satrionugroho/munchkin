defmodule MunchkinWeb.API.V1.ProductJSON do
  def render("index.json", %{data: products}) do
    %{
      data: Enum.map(products, &product_view/1),
      messages: [],
      actions: "get product"
    }
  end

  def product_view(%{name: name} = product) when name == "Institutional" do
    Map.take(product, [
      :name,
      :description,
      :features,
      :limitations,
      :currency,
      :button_text,
      :is_popular,
      :subtitle
    ])
    |> Map.merge(%{
      product_name: product.name,
      price: "Contact Us"
    })
  end

  def product_view(product) do
    Map.take(product, [
      :description,
      :features,
      :limitations,
      :currency,
      :button_text,
      :is_popular,
      :subtitle
    ])
    |> Map.merge(%{
      product_name: product.name,
      price: Decimal.to_string(product.price)
    })
  end
end
