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

  def safe_to_atom(string) do
    try do
      String.to_existing_atom(string)
    catch
      _ -> String.to_atom(string)
    end
  end

  def parse_search_params(params \\ %{}) do
    valid_attrs = ~w(page per q sort)
    default = [page: 1, per: 10, q: "", sort: "asc"]

    Enum.reduce(params, default, fn {key, val}, acc ->
      case Enum.member?(valid_attrs, to_string(key)) do
        true -> Keyword.put(acc, safe_to_atom(key), params_value(key, val))
        _ -> acc
      end
    end)
  end

  defp params_value(key, val) when key in ["page", "per"] and is_bitstring(val) do
    try do
      String.to_integer(val)
    catch
      _ -> 10
    end
  end

  defp params_value(_, val), do: val

  def html_form(mod, params \\ %{})

  def html_form(%mod{} = map, params) do
    mod.changeset(map, params)
    |> Phoenix.Component.to_form()
  end

  def html_form(attrs, _params), do: attrs
end
