defmodule Munchkin.Engine.Factset.Repo do
  use Ecto.Repo,
    otp_app: :munchkin,
    adapter: Ecto.Adapters.MyXQL
end
