defmodule Munchkin.Engine.Factset.Fundamental do
  alias Munchkin.Engine.Factset.DB

  @derive JSON.Encoder
  @derive Jason.Encoder
  @enforce_keys [:ticker, :data]
  defstruct [:ticker, :data]

  @type data :: map()
  @type t :: %__MODULE__{
          ticker: String.t(),
          data: [data()]
        }

  defimpl Inspect, for: __MODULE__ do
    def inspect(%_mod{ticker: ticker}, _opts) do
      "#Factset.Fundamental<ticker: #{ticker}>, data: ...>"
    end
  end

  def get(ticker, opts \\ []) do
    {_type, mod} = DB.type()

    apply(mod, :get, [ticker, opts])
    |> Map.values()
    |> then(&struct(__MODULE__, ticker: ticker, data: &1))
  end
end
