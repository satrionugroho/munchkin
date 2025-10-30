defmodule Munchkin.Engine.Factset.DBConnection do
  def get(ticker, opts \\ []) do
    :logger.warning("not implemented yet due to technical issue")

    :logger.warning(
      "better to use local connection to get #{inspect(ticker)} with options #{inspect(opts)}"
    )

    {:error, "not implemented"}
  end
end
