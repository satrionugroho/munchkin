defmodule MunchkinWeb.API.V1.AnalyzeJSON do
  def render("index.json", %{data: data}) do
    %{
      data: data,
      messages: [],
      actions: "get analized data"
    }
  end
end
