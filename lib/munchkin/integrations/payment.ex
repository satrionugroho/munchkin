defmodule Munchkin.Integrations.Payment do
  @doc "Defines a function to register a user"
  @callback register_user(params :: Map.t()) ::
              {:ok, result :: Map.t()} | {:error, message :: String.t()}

  @doc "Defines a function to create a subscription"
  @callback subscribe(params :: Map.t()) ::
              {:ok, result :: Map.t()} | {:error, message :: String.t()}

  @doc "Defines a function to stop a subscription"
  @callback unsubscribe(params :: Map.t()) ::
              {:ok, result :: Map.t()} | {:error, message :: String.t()}

  @doc "Defines a function to define the provider"
  @callback name() :: String.t()

  @doc "Defines a function to create parameter for a unsubscribe"
  @callback compose_unsubscribe_params(user_id :: String.t(), plan :: Map.t()) :: Map.t()

  @doc "Defines a function to create parameter for a subscription"
  @callback compose_subscription_params(user_id :: String.t(), plan :: Map.t()) :: Map.t()

  def create_subscription(user, product) do
    with {:ok, customer_id} <- get_specific_customer_id(user, engine()),
         params <- apply(engine(), :compose_subscription_params, [customer_id, product]),
         {:ok, _res} = result <- action(:subscribe, params) do
      result
    else
      err -> err
    end
  end

  def action(type, params) when type in [:register_user, :subscribe, :unsubscribe] do
    apply(engine(), type, [params])
  end

  def action(type, _params) do
    raise FunctionClauseError, "cannot find function with name #{inspect(type)}"
  end

  defp engine do
    Application.get_env(:munchkin, __MODULE__, [])
    |> Keyword.get(:engine, Munchkin.ThirdParty.Xendit)
  end

  defp get_specific_customer_id(%{integrations: []} = user, module) do
    case create_new_integration(user, module) do
      {:ok, data} ->
        data

      err ->
        raise RuntimeError,
              "cannot create new integration for #{inspect(module)} with err=#{inspect(err)}"
    end
    |> Map.get(:idempotency_id)
    |> then(fn d -> {:ok, d} end)
  end

  defp get_specific_customer_id(%{integrations: integrations} = user, module) do
    name = apply(module, :name, [])

    Enum.find(integrations, &String.equivalent?(&1.provider, name))
    |> case do
      nil -> create_new_integration(user, module)
      data -> data
    end
    |> Map.get(:idempotency_id)
    |> then(fn d -> {:ok, d} end)
  end

  defp create_new_integration(user, module) do
    case action(:register_user, %{given_names: user.firstname}) do
      {:ok, data} ->
        Munchkin.Accounts.create_integration(user, %{
          idempotency_id: Map.get(data, "id"),
          provider: apply(module, :name, [])
        })

      err ->
        err
    end
  end
end
