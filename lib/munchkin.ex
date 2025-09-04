defmodule Munchkin do
  @moduledoc """
  Munchkin keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def application_name do
    Application.get_env(:munchkin, __MODULE__, [])
    |> Keyword.get(:name)
  end
end
