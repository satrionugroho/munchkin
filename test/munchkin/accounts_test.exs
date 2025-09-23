defmodule Munchkin.AccountsTest do
  use Munchkin.DataCase

  alias Munchkin.Accounts

  describe "users" do
    alias Munchkin.Accounts.User

    import Munchkin.AccountsFixtures

    @invalid_attrs %{firstname: nil, lastname: nil, email: nil, password_hash: nil, verified_at: nil, sign_in_count: nil, sign_in_attempt: nil}

    test "list_users/0 returns all users" do
      user = user_fixture()
      assert Accounts.list_users() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Accounts.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      valid_attrs = %{firstname: "some firstname", lastname: "some lastname", email: "some email", password_hash: "some password_hash", verified_at: ~N[2025-08-26 06:24:00], sign_in_count: 42, sign_in_attempt: 42}

      assert {:ok, %User{} = user} = Accounts.create_user(valid_attrs)
      assert user.firstname == "some firstname"
      assert user.lastname == "some lastname"
      assert user.email == "some email"
      assert user.password_hash == "some password_hash"
      assert user.verified_at == ~N[2025-08-26 06:24:00]
      assert user.sign_in_count == 42
      assert user.sign_in_attempt == 42
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()
      update_attrs = %{firstname: "some updated firstname", lastname: "some updated lastname", email: "some updated email", password_hash: "some updated password_hash", verified_at: ~N[2025-08-27 06:24:00], sign_in_count: 43, sign_in_attempt: 43}

      assert {:ok, %User{} = user} = Accounts.update_user(user, update_attrs)
      assert user.firstname == "some updated firstname"
      assert user.lastname == "some updated lastname"
      assert user.email == "some updated email"
      assert user.password_hash == "some updated password_hash"
      assert user.verified_at == ~N[2025-08-27 06:24:00]
      assert user.sign_in_count == 43
      assert user.sign_in_attempt == 43
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user(user, @invalid_attrs)
      assert user == Accounts.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Accounts.change_user(user)
    end
  end

  describe "user_tokens" do
    alias Munchkin.Accounts.UserToken

    import Munchkin.AccountsFixtures

    @invalid_attrs %{type: nil, token: nil, valid_until: nil, used_at: nil}

    test "list_user_tokens/0 returns all user_tokens" do
      user_token = user_token_fixture()
      assert Accounts.list_user_tokens() == [user_token]
    end

    test "get_user_token!/1 returns the user_token with given id" do
      user_token = user_token_fixture()
      assert Accounts.get_user_token!(user_token.id) == user_token
    end

    test "create_user_token/1 with valid data creates a user_token" do
      valid_attrs = %{type: 42, token: "some token", valid_until: ~N[2025-08-26 07:33:00], used_at: ~N[2025-08-26 07:33:00]}

      assert {:ok, %UserToken{} = user_token} = Accounts.create_user_token(valid_attrs)
      assert user_token.type == 42
      assert user_token.token == "some token"
      assert user_token.valid_until == ~N[2025-08-26 07:33:00]
      assert user_token.used_at == ~N[2025-08-26 07:33:00]
    end

    test "create_user_token/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user_token(@invalid_attrs)
    end

    test "update_user_token/2 with valid data updates the user_token" do
      user_token = user_token_fixture()
      update_attrs = %{type: 43, token: "some updated token", valid_until: ~N[2025-08-27 07:33:00], used_at: ~N[2025-08-27 07:33:00]}

      assert {:ok, %UserToken{} = user_token} = Accounts.update_user_token(user_token, update_attrs)
      assert user_token.type == 43
      assert user_token.token == "some updated token"
      assert user_token.valid_until == ~N[2025-08-27 07:33:00]
      assert user_token.used_at == ~N[2025-08-27 07:33:00]
    end

    test "update_user_token/2 with invalid data returns error changeset" do
      user_token = user_token_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user_token(user_token, @invalid_attrs)
      assert user_token == Accounts.get_user_token!(user_token.id)
    end

    test "delete_user_token/1 deletes the user_token" do
      user_token = user_token_fixture()
      assert {:ok, %UserToken{}} = Accounts.delete_user_token(user_token)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user_token!(user_token.id) end
    end

    test "change_user_token/1 returns a user_token changeset" do
      user_token = user_token_fixture()
      assert %Ecto.Changeset{} = Accounts.change_user_token(user_token)
    end
  end

  describe "admins" do
    alias Munchkin.Accounts.Admin

    import Munchkin.AccountsFixtures

    @invalid_attrs %{email: nil, fullname: nil, password_hash: nil}

    test "list_admins/0 returns all admins" do
      admin = admin_fixture()
      assert Accounts.list_admins() == [admin]
    end

    test "get_admin!/1 returns the admin with given id" do
      admin = admin_fixture()
      assert Accounts.get_admin!(admin.id) == admin
    end

    test "create_admin/1 with valid data creates a admin" do
      valid_attrs = %{email: "some email", fullname: "some fullname", password_hash: "some password_hash"}

      assert {:ok, %Admin{} = admin} = Accounts.create_admin(valid_attrs)
      assert admin.email == "some email"
      assert admin.fullname == "some fullname"
      assert admin.password_hash == "some password_hash"
    end

    test "create_admin/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_admin(@invalid_attrs)
    end

    test "update_admin/2 with valid data updates the admin" do
      admin = admin_fixture()
      update_attrs = %{email: "some updated email", fullname: "some updated fullname", password_hash: "some updated password_hash"}

      assert {:ok, %Admin{} = admin} = Accounts.update_admin(admin, update_attrs)
      assert admin.email == "some updated email"
      assert admin.fullname == "some updated fullname"
      assert admin.password_hash == "some updated password_hash"
    end

    test "update_admin/2 with invalid data returns error changeset" do
      admin = admin_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_admin(admin, @invalid_attrs)
      assert admin == Accounts.get_admin!(admin.id)
    end

    test "delete_admin/1 deletes the admin" do
      admin = admin_fixture()
      assert {:ok, %Admin{}} = Accounts.delete_admin(admin)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_admin!(admin.id) end
    end

    test "change_admin/1 returns a admin changeset" do
      admin = admin_fixture()
      assert %Ecto.Changeset{} = Accounts.change_admin(admin)
    end
  end
end
