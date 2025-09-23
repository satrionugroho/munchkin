defmodule Munchkin.Subscription do
  @moduledoc """
  The Subscription context.
  """

  import Ecto.Query, warn: false
  alias Munchkin.Repo

  alias Munchkin.Subscription.{Product, Plan}

  @doc """
  Returns the list of products.

  ## Examples

      iex> list_products()
      [%Product{}, ...]

  """
  def list_products(lang \\ "en") do
    Munchkin.Cache.get_or_update_with_ttl(
      {"products", "list"},
      fn ->
        Repo.all(Product)
        |> then(fn data -> {:ok, data} end)
      end,
      :timer.hours(1)
    )
    |> elem(1)
    |> Enum.filter(&Kernel.==(&1.lang, lang))
  end

  def get_product(id) when is_number(id) do
    query = from p in Product, where: p.id == ^id, limit: 1

    query
    |> select([c], %{c | free: c.name == "Free", key: fragment("lower(?)", c.name)})
    |> Repo.one()
  end

  def get_product(id) do
    try do
      String.to_integer(id)
      |> get_product()
    rescue
      _ -> nil
    end
  end

  def get_product_by_name(raw, lang \\ "en") do
    name = String.downcase(raw)

    Munchkin.Cache.get_or_update_with_ttl(
      {"products", name},
      fn ->
        query = from p in Product, where: ilike(p.key, ^name), limit: 2

        query
        |> Repo.all()
        |> case do
          [] -> {:error, "cannot find free product"}
          products -> {:ok, products}
        end
      end,
      :timer.hours(1)
    )
    |> then(fn
      {:ok, data} ->
        {:ok, Enum.find(data, &Kernel.==(&1.lang, lang))}

      {:error, _} = res ->
        res
    end)
  end

  def define_product(%Munchkin.Accounts.User{} = user, default) do
    now = DateTime.utc_now()

    case user.subscriptions do
      [] ->
        default

      [%{ended_at: ended_at} = plan | _list] when is_nil(ended_at) ->
        plan.product

      [%{ended_at: ended_at} = plan | _list] ->
        case DateTime.after?(now, ended_at) do
          true -> default
          _ -> plan.product
        end
    end
  end

  def free_tier(lang \\ "en"), do: get_product_by_name("basic", lang)

  def free_tier! do
    case free_tier() do
      {:ok, data} -> data
      {:error, err} -> raise Ecto.NoResultsError, err
    end
  end

  def create_subscription(params) do
    with {:ok, user} <- get_specific_user(params),
         {:ok, product} <- get_desired_product(params) do
      Repo.transact(fn ->
        {:ok, resp} = do_integration(user, product)

        %Plan{}
        |> Plan.changeset(%{
          idempotency_id: Map.get(resp, "reference_id"),
          user_id: user.id,
          tier: product.tier,
          metadata: resp,
          currency: product.currency
        })
        |> Repo.insert()
      end)
    else
      true -> {:error, "free product cannot be subscribe"}
    end
  end

  defp do_integration(user, product) when product.is_free != true do
    Munchkin.Integrations.Payment.create_subscription(user, product)
  end

  defp do_integration(_user, _product), do: {:ok, %{}}

  defp get_specific_user(params) do
    params
    |> Enum.find(fn {key, _value} -> to_string(key) == "user_id" end)
    |> case do
      nil ->
        {:error, "user not found"}

      {_, value} ->
        Munchkin.Accounts.get_user(value, [:subscriptions, :integrations])
    end
    |> case do
      %Munchkin.Accounts.User{} = user -> {:ok, user}
      err -> err
    end
  end

  defp get_desired_product(params) do
    params
    |> Enum.find(fn {key, _value} -> to_string(key) == "product_id" end)
    |> case do
      nil -> {:error, "product not found"}
      {_, value} -> get_product(value)
    end
    |> case do
      %Munchkin.Subscription.Product{} = product -> {:ok, product}
      err -> err
    end
  end

  def get_plan(id) do
    query = from p in Plan, where: p.id == ^id, preload: [:product, :payments], limit: 1
    Repo.one(query)
  end
end
