defmodule Munchkin.Langchain.Advanced do
  alias Munchkin.Langchain.Engine
  alias LangChain.Message

  def system_message do
    Message.new_system!(~s"""
    You are a expert investment professional. You MUST talk about the investing terms and convince the explaining to a senior investment analyst.
    You need to answer with the following rules. The rules are:
    1. Must calculate the verdict from given data from user.
    2. The user data is ONLY about Company detail, Current price, Technical data, Quality models, Valuation models and Relative models.
    3. Give the answer in format. Our Verdict and followed by a simple reasoning why you conclude the result.
    4. The Verdict SHOULD be one of Strong Buy, Buy, Buy with Caution, Buy with Consideration, Neutral, Avoid, Avoid with Consideration or Strong Avoid.
    5. MUST explained the reason covered in Valuation, Quality, Risk and Projections.
    6. MUST identify the company is in "Value Trap" or not.
    7. You CAN use the other method like Weighted Average based on Margin of Safety or other tools.
    8. Ideally you NEED to calculate the "Risk-Adjusted" fair value if possible.
    9. Do not asked question!
    """)
  end

  def compose_message(params) do
    Engine.user_message(params)
    |> add_simple_technical_options(params)
  end

  defp add_simple_technical_options(msg, %{"analizer" => an}) do
    case Map.get(an, "ticker") do
      ticker when is_bitstring(ticker) and ticker != "" -> technical_message_details(msg, ticker)
      _ -> msg
    end
  end

  defp technical_message_details(msg, ticker) do
    ticker
    msg
  end
end
