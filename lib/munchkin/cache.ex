defmodule Munchkin.Cache do
  use Nebulex.Cache,
    otp_app: :munchkin,
    adapter: Nebulex.Adapters.Local
end
