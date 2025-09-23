defmodule Munchkin.Cache do
  use Nebulex.Cache,
    otp_app: :munchkin,
    adapter: Nebulex.Adapters.Local

  def get_or_update(key, fun_or_mfa) do
    case __MODULE__.get(key) do
      nil -> eval_and_put(key, fun_or_mfa, :infinity)
      {:ok, nil} -> eval_and_put(key, fun_or_mfa, :infinity)
      data -> data
    end
  end

  def get_or_update_with_ttl(key, fun_or_mfa, ttl) do
    case __MODULE__.get(key) do
      nil -> eval_and_put(key, fun_or_mfa, ttl)
      {:ok, nil} -> eval_and_put(key, fun_or_mfa, ttl)
      data -> data
    end
  end

  defp eval_and_put(key, {module, fun, arity}, ttl) when is_atom(module) and is_atom(fun) do
    case apply(module, fun, arity) do
      {:ok, data} = returning ->
        _ = __MODULE__.put(key, data)
        _ = __MODULE__.expire(key, ttl)
        returning

      err ->
        {:error, "function evaluation error with #{inspect(err)}"}
    end
  end

  defp eval_and_put(key, fun, ttl) when is_function(fun) do
    case apply(fun, []) do
      {:ok, data} = returning ->
        _ = __MODULE__.put(key, data)
        _ = __MODULE__.expire(key, ttl)
        returning

      err ->
        {:error, "function evaluation error with #{inspect(err)}"}
    end
  end

  defp eval_and_put(key, _, _), do: {:error, "cannot evaluate function from key = #{key}"}
end
