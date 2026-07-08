defmodule UserMigrator do
  def migrate() do
    [
      create_user(),
      create_admin()
    ]
    |> Enum.map(&IO.inspect/1)
  end

  defp create_admin() do
    Munchkin.Accounts.create_admin(%{
      email: "admin@munchkin.com",
      fullname: "Admin 1",
      password: "munchkin1234M"
    })
  end

  defp create_user() do
    Munchkin.Repo.transact(fn ->
    {:ok, user} = Munchkin.Accounts.create_user(%{
      firstname: "Satrio",
      lastname: "Nugroho",
      email: "satrio.nu27@gmail.com",
      password: "satrio1234S",
      email_source: "web"
    })

      {:ok, token} = Munchkin.Accounts.create_user_token(%{
        user: user,
        valid_until: DateTime.utc_now() |> DateTime.shift(day: 2),
        type: Munchkin.Accounts.UserToken.email_verification_type()
      })

          Munchkin.Accounts.update_user_token(token, %{used_at: DateTime.utc_now(:second)})
          Munchkin.Accounts.update_user(token.user_id, %{}, :email_verified_changeset)

          Munchkin.Subscription.create_subscription(%{
            user_id: token.user_id,
            product_id: Munchkin.Subscription.free_tier!().id
          })

    end)
  end
end


UserMigrator.migrate()
