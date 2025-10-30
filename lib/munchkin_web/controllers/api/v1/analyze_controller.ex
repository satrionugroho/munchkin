defmodule MunchkinWeb.API.V1.AnalyzeController do
  alias Munchkin.Inventory
  use MunchkinWeb, :controller

  def index(conn, %{"ticker" => ticker, "analyzer" => analyzer})
      when ticker != "" and analyzer != "" do
    with product <- get_current_product(conn),
         source <- get_current_source(conn),
         {:ok, data} <- get_analized_data(source, product, ticker, analyzer) do
      render(conn, :index, data: data)
    else
      _ -> render(conn, :error, gettext("cannot analyze the data"))
    end
  end

  defp get_analized_data(source, product, ticker, analizer) do
    get_period_range(product.tier)
    |> then(&Inventory.get_fundamental_data(ticker, &1))
    |> parse_with_source(source, analizer)
  end

  defp parse_with_source(data, "excel", _analizer), do: {:ok, data}

  defp parse_with_source(data, _, _analizer) do
    {:ok, data}
  end

  defp get_period_range(tier) do
    cd = Date.utc_today()

    get_year_range(tier)
    |> Enum.map(fn iter ->
      Date.shift(cd, year: -iter, month: -1)
      |> Date.range(cd, 90)
      |> Enum.map(fn %{year: year} = d ->
        fiscal = Inventory.fiscal_quarter(d)

        year
        |> Kernel.to_string()
        |> Kernel.<>(fiscal)
      end)
    end)
    |> :lists.flatten()
  end

  defp get_year_range(1), do: Range.new(0, 2)
  defp get_year_range(2), do: Range.new(0, 3)
  defp get_year_range(3), do: Range.new(0, 5)
  defp get_year_range(_), do: Range.new(0, 10)
end
