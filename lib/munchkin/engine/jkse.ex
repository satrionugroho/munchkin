defmodule Munchkin.Engine.Jkse do
  @after_compile __MODULE__.CLI

  def id, do: __MODULE__.Config.app_id()
end
