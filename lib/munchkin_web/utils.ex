defmodule MunchkinWeb.Utils do
  def decode_token(%Munchkin.Accounts.UserToken{} = token) do
    valid_until_bytes =
      DateTime.utc_now(:second)
      |> shifter(token)
      |> DateTime.to_unix()
      |> :binary.encode_unsigned()
      |> :binary.bin_to_list()
      |> :lists.reverse()
      |> IO.iodata_to_binary()

    Base.url_encode64(valid_until_bytes <> token.token)
  end

  defp shifter(datetime, token) do
    case token.type do
      3 -> DateTime.shift(datetime, month: 2)
      _ -> DateTime.shift(datetime, day: 14)
    end
  end
end
