defmodule Munchkin.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Munchkin.Accounts` context.
  """

  @doc """
  Generate a unique user email.
  """
  def unique_user_email, do: "some email#{System.unique_integer([:positive])}"

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: unique_user_email(),
        firstname: "some firstname",
        lastname: "some lastname",
        password_hash: "some password_hash",
        sign_in_attempt: 42,
        sign_in_count: 42,
        verified_at: ~N[2025-08-26 06:24:00]
      })
      |> Munchkin.Accounts.create_user()

    user
  end

  @doc """
  Generate a user_token.
  """
  def user_token_fixture(attrs \\ %{}) do
    {:ok, user_token} =
      attrs
      |> Enum.into(%{
        token: "some token",
        type: 42,
        used_at: ~N[2025-08-26 07:33:00],
        valid_until: ~N[2025-08-26 07:33:00]
      })
      |> Munchkin.Accounts.create_user_token()

    user_token
  end

  @doc """
  Generate a admin.
  """
  def admin_fixture(attrs \\ %{}) do
    {:ok, admin} =
      attrs
      |> Enum.into(%{
        email: "some email",
        fullname: "some fullname",
        password_hash: "some password_hash"
      })
      |> Munchkin.Accounts.create_admin()

    admin
  end
end
