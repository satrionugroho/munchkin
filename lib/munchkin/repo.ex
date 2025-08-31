defmodule Munchkin.Repo do
  use Ecto.Repo,
    otp_app: :munchkin,
    adapter: Ecto.Adapters.Postgres
end
