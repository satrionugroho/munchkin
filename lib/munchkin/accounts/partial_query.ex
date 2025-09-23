defmodule Munchkin.Accounts.PartialQuery do
  import Ecto.Query, warn: false

  alias Munchkin.Accounts.UserToken

  def access_tokens_query do
    from t in UserToken,
      where: t.type == ^UserToken.access_token_type(),
      order_by: [desc: t.id]
  end

  def two_factor_tokens_query, do: token_query(UserToken.two_factor_type())

  def refresh_tokens_query, do: token_query(UserToken.refresh_token_type())

  def user_preloader(types \\ [:access_tokens, :two_factor_tokens, :subscriptions]) do
    Enum.reduce(types, [], fn key, acc ->
      fun = String.to_existing_atom("#{key}_query")
      query = apply(__MODULE__, fun, [])
      Keyword.put_new(acc, key, query)
    end)
  end

  def active_token_query(type, token) do
    query = token_query(type)

    from q in query, where: q.token == ^token
  end

  def token_query(type) do
    now = DateTime.utc_now(:second)

    from t in UserToken,
      where: t.type == ^type and is_nil(t.used_at) and t.valid_until > ^now,
      order_by: [desc: t.id]
  end

  def get_token_query(token, opts \\ []) do
    case Keyword.get(opts, :with_limit, false) do
      true -> from t in UserToken, where: t.token == ^token, limit: 1
      _ -> from t in UserToken, where: t.token == ^token
    end
  end

  def delete_unused_2fa_token(user_id) do
    type = UserToken.two_factor_type()
    one_day = DateTime.utc_now(:second) |> DateTime.shift(day: 1)

    from t in UserToken,
      where:
        t.type == ^type and is_nil(t.used_at) and t.user_id == ^user_id and
          t.valid_until < ^one_day
  end

  def subscriptions_query do
    from s in Munchkin.Subscription.Plan,
      preload: ^[product: tier_extended_query()],
      preload: :payments,
      limit: 5,
      order_by: [desc: s.inserted_at]
  end

  def tier_extended_query() do
    query = from(p in Munchkin.Subscription.Product, limit: 1)

    query
    |> select([c], %{c | free: c.name == "Free", key: fragment("lower(?)", c.key)})
  end

  def integrations_query do
    from(i in Munchkin.Accounts.Integration)
  end
end
