defmodule Munchkin.Dashboard do
  import Ecto.Query, warn: false

  alias Munchkin.Subscription

  def total_users do
    key = {__MODULE__, "total_users"}

    Munchkin.Cache.get_or_update(key, fn ->
      user_count =
        from(p in Subscription.Plan,
          where: p.product_id == parent_as(:product).id,
          select: count(p.user_id)
        )

      query =
        from p in Subscription.Product,
          as: :product,
          select: %{
            name: p.name,
            count: subquery(user_count),
            key: fragment("lower(?)", p.name)
          }

      Munchkin.Repo.all(query)
      |> then(fn x -> {:ok, x} end)
    end)
    |> tap(fn _ -> Munchkin.Cache.expire(key, :timer.minutes(30)) end)
  end
end
