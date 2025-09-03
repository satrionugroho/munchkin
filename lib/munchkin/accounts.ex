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
    query = from t in UserToken, preload: [:user], where: t.token == ^token and t.valid_until >= ^now and is_nil(t.used_at) and t.type == ^UserToken.two_factor_type(), limit: 1
    Repo.one(query)
  end

  @doc """
  Create a single forgot password or nil

  ## Examples

    iex> create_user_forgot_password_token(user)
    %UserToken{id: id}
  """
  def create_user_forgot_password_token(%User{} = user) do
    user.user_tokens
    |> Enum.filter(&Kernel.==(&1.type, UserToken.forgot_password_type()))
    |> Enum.find(&Kernel.is_nil(&1.used_at))
    |> case do
      %UserToken{} = token -> {:ok, token}
      _ ->
        attrs = %{
          user: user,
          valid_until: NaiveDateTime.utc_now(:second) |> NaiveDateTime.shift(day: 7),
          type: UserToken.forgot_password_type()
        }
        create_user_token(attrs)
    end
  end
  def create_user_forgot_password_token(user_id) do
    get_user!(user_id)
    |> create_user_forgot_password_token()
  end

  @doc """
  Get a single forgot password or nil

  ## Examples

    iex> reset_password_from_token(token, password)
    %UserToken{id: id}
  """
  def reset_password_from_token(token, password) do
    now = NaiveDateTime.utc_now(:second)
    query = from t in UserToken, preload: [:user], where: t.token == ^token and t.type == ^UserToken.forgot_password_type() and is_nil(t.used_at) and t.valid_until >= ^now, limit: 1
    case Repo.one(query) do
      nil -> {:error, "token is expired or invalid"}
      %UserToken{} = token -> do_reset_password(token, password)
    end
  end

  defp do_reset_password(%{user: user} = token, password) do
    Repo.transact(fn -> 
      {:ok, updated_user} = update_user(user, %{password: password})
      {:ok, token} = update_user_token(token, %{used_at: NaiveDateTime.utc_now(:second)})

      {:ok, %{user: updated_user, token: token}}
    end)
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
  Creates user access token

  ## Examples

      iex> create_user_access_token(%User{id: value})
      {:ok, %UserToken{}}

  """
  def create_user_access_token(%User{} = user) do  
    user.user_tokens
    |> Enum.filter(fn token -> 
      NaiveDateTime.after?(token.valid_until, NaiveDateTime.utc_now())
      |> then(fn first -> 
        Kernel.==(token.type, UserToken.access_token_type())
        |> Kernel.and(first)
      end)
    end)
    |> do_create_access_token_with_refresh(user)
  end
  def create_user_access_token(user_id) do
    get_user!(user_id)
    |> create_user_access_token()
  end

  defp do_create_access_token_with_refresh(tokens, user) do
    token_ids = Enum.filter(tokens, &Kernel.is_nil(&1.used_at)) |> Enum.map(&(&1.id))
    query = from t in UserToken, where: t.id in ^token_ids
    updates = [set: [used_at: NaiveDateTime.utc_now(:second)]]
    attrs = %{
      user: user,
      valid_until: NaiveDateTime.utc_now(:second) |> NaiveDateTime.shift(day: 7),
      type: UserToken.access_token_type()
    }

    Repo.transact(fn ->
      Repo.update_all(query, updates)
      {:ok, access} = case create_user_token(attrs) do
        {:ok, _access} = ret ->
          Enum.map(tokens, &Munchkin.Cache.delete(&1.token))
          ret
        err -> err
      end
      refresh = should_generate_refresh_token?(user)


      {:ok, %{access: access, refresh: refresh}}
    end)
  end

  defp should_generate_refresh_token?(user) do
    user.user_tokens
    |> Enum.find(&Kernel.==(&1.type, UserToken.refresh_token_type()))
    |> case do
      %UserToken{valid_until: valid} = token -> [NaiveDateTime.before?(valid, NaiveDateTime.utc_now()), token]
        _ -> [true, nil]
    end
    |> then(fn
      [true, _] -> 
        attrs = %{
          user: user,
          valid_until: NaiveDateTime.utc_now(:second) |> NaiveDateTime.shift(day: 7),
          type: UserToken.refresh_token_type()
        }
        {:ok, token} = create_user_token(attrs)
        token
      [_, token] -> token
    end)
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
