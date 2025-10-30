defmodule Munchkin.Inventory.Fundamental.Gate do
  alias Munchkin.Repo
  alias Munchkin.Inventory.AssetSource
  alias Munchkin.Inventory.Asset
  alias Munchkin.Inventory.Fundamental

  def insert_fundamental_data(mod, %{"ticker" => ticker, "period" => period} = params) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:params, fn _repo, _ ->
      Munchkin.Utils.MapString.perform(params)
      |> then(fn p -> {:ok, Map.put(p, "asset_id", ticker)} end)
    end)
    |> Ecto.Multi.run(:fundamental_exists, fn repo, %{params: %{"source_id" => ref}} ->
      case Munchkin.Inventory.get_fundamental_by_period(ticker, period, repo: repo, ref_id: ref) do
        nil -> {:ok, nil}
        data -> {:ok, data}
      end
    end)
    |> Ecto.Multi.merge(fn
      %{fundamental_exists: fun, params: params} when is_nil(fun) ->
        Ecto.Multi.new()
        |> Ecto.Multi.run(
          :asset,
          &get_data_from_given_params(&1, %{params: params, left: &2}, "asset", Asset)
        )
        |> Ecto.Multi.run(
          :source,
          &get_data_from_given_params(&1, %{params: params, left: &2}, "source", AssetSource)
        )

      %{fundamental_exists: fun} ->
        Ecto.Multi.new()
        |> Ecto.Multi.put(:source, fun.source)
        |> Ecto.Multi.put(:asset, fun.asset)
    end)
    |> Ecto.Multi.insert(:fundamental, &fundamental_changeset/1)
    |> Ecto.Multi.insert(:channel, &fundamental_channel_changeset(mod, &1))
    |> Repo.transact()
  end

  defp fundamental_changeset(%{fundamental_exists: fun} = opts) when is_nil(fun) do
    %{params: params, source: source, asset: asset} = opts

    %Fundamental{}
    |> Fundamental.changeset(%{asset: asset, source: source, period: Map.get(params, "period")})
  end

  defp fundamental_changeset(opts) do
    %{params: params, source: source, asset: asset, fundamental_exists: fun} = opts

    options = %{
      "asset" => asset,
      "source" => source,
      "period" => Map.get(params, "period"),
      "parent" => fun,
      "metadata" => %{
        "type" => "revision",
        "revise_at" => DateTime.utc_now(:second) |> DateTime.to_string()
      }
    }

    %Fundamental{}
    |> Fundamental.changeset(options)
  end

  defp fundamental_channel_changeset(mod, %{fundamental: data} = opts) do
    %{params: params} = opts
    changes = Map.put(params, "id", data.id)

    struct(mod)
    |> then(&apply(mod, :changeset, [&1, changes]))
  end

  defp validate_data_with_module(mod, %given{} = data) when mod == given, do: {:ok, data}

  defp validate_data_with_module(mod, data),
    do: {:error, "cannot validate the given data with #{inspect(mod)}, given #{inspect(data)}"}

  def get_data_from_given_params(repo, opts, type, module) do
    params = Map.get(opts, :params, %{})

    case Map.get(params, type) do
      nil ->
        fun = String.to_existing_atom("get_#{type}")
        id = Map.get(params, "#{type}_id")
        apply(Munchkin.Inventory, fun, [id, [repo: repo]])

      data ->
        data
    end
    |> then(&validate_data_with_module(module, &1))
  end
end
