defmodule Munchkin.Engine.Factset do
  def id, do: __MODULE__.DB.app_id()
end
