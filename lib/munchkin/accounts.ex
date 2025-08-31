defmodule Munchkin.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Munchkin.Repo

  alias Munchkin.Accounts.{User, UserToken}

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id) do 
    query = from u in User, preload: [:user_tokens], where: u.id == ^id, limit: 1
    case Repo.one(query) do
      nil -> raise Ecto.NoResultsError, "cannot find user"
      user -> user
    end
  end

  @doc """
  Gets a single user by email.

  ## Examples

      iex> get_user_by_email("john.doe@gmail.com")
      %User{}

      iex> get_user_by_email!("non_exist_email@mgial.com")
      nil

  """
  def get_user_by_email(email) when is_bitstring(email) do
    sanitized = String.downcase(email)
    query = from u in User, preload: [:user_tokens], where: u.email == ^sanitized, limit: 1
    Repo.one(query)
  end

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs, changeset_fun \\ :changeset) do
    apply(User, changeset_fun, [user, attrs])
    |> Repo.update()
  end

  @doc """
  Deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  @doc """
  Gets a single user_token.

  Raises `Ecto.NoResultsError` if the User token does not exist.

  ## Examples

      iex> get_user_token("token")
      %UserToken{}

      iex> get_user_token("not valid token")
      ** (Ecto.NoResultsError)

  """
  def get_user_token(token) do
    now = DateTime.utc_now(:second)
    query = from t in UserToken, preload: [user: [:user_tokens]], where: t.token == ^token and t.valid_until >= ^now and is_nil(t.used_at), limit: 1
    Repo.one(query)
  end

  @doc """
  Gets a single mfa token or nil

  ## Examples

      iex> get_user_mfa_token("token")
      %UserToken{}

      iex> get_user_mfa_token("not valid token")
      ** (Ecto.NoResultsError)

  """
  def get_user_mfa_token(token) do
    now = DateTime.utc_now(:second)
    query = from t in UserToken, preload: [:user], where: t.token == ^token and t.valid_until >= ^now and is_nil(t.used_at) and t.type == 5, limit: 1
    Repo.one(query)
  end

  @doc """
  Creates a user_token.

  ## Examples

      iex> create_user_token(%{field: value})
      {:ok, %UserToken{}}

      iex> create_user_token(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_token(attrs) do
    %UserToken{}
    |> UserToken.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user_token.

  ## Examples

      iex> update_user_token(user_token, %{field: new_value})
      {:ok, %UserToken{}}

      iex> update_user_token(user_token, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_token(%UserToken{} = user_token, attrs) do
    user_token
    |> UserToken.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user_token.

  ## Examples

      iex> delete_user_token(user_token)
      {:ok, %UserToken{}}

      iex> delete_user_token(user_token)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_token(%UserToken{} = user_token) do
    Repo.delete(user_token)
  end
end
