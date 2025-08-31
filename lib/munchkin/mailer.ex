defmodule Munchkin.Mailer do
  use Swoosh.Mailer, otp_app: :munchkin

  def sender do
    config = Application.get_env(:munchkin, __MODULE__, [])

    {Keyword.get(config, :sender_name), Keyword.get(config, :sender_email)}
  end
end
