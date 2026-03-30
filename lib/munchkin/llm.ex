defmodule Munchkin.LLM do
  alias LangChain.Message
  alias LangChain.Chains.LLMChain

  def simple(params, opts \\ []) do
    llm = create_engine(opts)

    LLMChain.new!(%{llm: llm})
    |> LLMChain.add_messages([
      Munchkin.Langchain.Simple.system_message(),
      Munchkin.Langchain.Simple.compose_message(params)
    ])
    |> LLMChain.run()
  end

  def normal(params, opts \\ []) do
    llm = create_engine(opts)

    LLMChain.new!(%{llm: llm})
    |> LLMChain.add_messages([
      Munchkin.Langchain.Normal.system_message(),
      Munchkin.Langchain.Normal.compose_message(params)
    ])
    |> LLMChain.run()
  end

  def advanced(params, opts \\ []) do
    llm = create_engine(opts)

    LLMChain.new!(%{llm: llm})
    |> LLMChain.add_messages([
      Munchkin.Langchain.Advanced.system_message(),
      Munchkin.Langchain.Advanced.compose_message(params)
    ])
    |> LLMChain.run()
  end

  def quantamental(params, opts \\ []) do
    llm = create_engine(opts)

    LLMChain.new!(%{llm: llm})
    |> LLMChain.add_messages([
      Munchkin.Langchain.Quantamental.system_message(),
      Munchkin.Langchain.Quantamental.compose_message(params)
    ])
    |> LLMChain.run()
  end

  defp create_engine(opts) do
    case Keyword.get(opts, :engine) do
      e when is_atom(e) -> Munchkin.Langchain.Engine.create(engine: e)
      _ -> Munchkin.Langchain.Engine.create()
    end
  end
end
