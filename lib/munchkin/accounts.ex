defmodule Munchkin.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Munchkin.Repo

  alias Munchkin.Accounts.{PartialQuery, User, UserToken}

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
  def get_user!(id, relations \\ [:access_tokens, :two_factor_tokens]) do
    query =
      from u in User,
        preload: ^PartialQuery.user_preloader(relations),
        where: u.id == ^id,
        limit: 1

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

    query =
      from u in User,
        preload: ^PartialQuery.user_preloader(),
        where: u.email == ^sanitized,
        limit: 1

    Repo.one(query)
  end

  def get_user_by_access_token(token) when is_bitstring(token) do
    with [expired_at, valid_token] <- decode_user_token(token),
         query <- PartialQuery.active_token_query(UserToken.access_token_type(), valid_token),
         %UserToken{} = token <- Repo.one(query),
         {:ok, _user} = data <- verify_token_validity(token, expired_at) do
      data
    else
      {:error, _} = err -> err
      err -> err
    end
  end

  defp decode_user_token(token) do
    with {:ok, decoded_token} <- Base.url_decode64(token),
         <<head::binary-size(4)>> <> valid_token <- decoded_token,
         list_head <- :binary.bin_to_list(head),
         rev_head <- :lists.reverse(list_head),
         dt <- IO.iodata_to_binary(rev_head),
         dt_bytes <- :binary.decode_unsigned(dt),
         {:ok, expired_at} <- DateTime.from_unix(dt_bytes) do
      [expired_at, valid_token]
    else
      {:error, _} = err -> err
      err -> err
    end
  end

  defp verify_token_validity(token, datetime) do
    now = DateTime.utc_now()

    case DateTime.after?(datetime, now) do
      true -> {:ok, get_user!(token.user_id)}
      _ -> {:error, "token is invalid"}
    end
  end

  @doc """
  Get user by refresh token

  ## Examples

      iex> get_user_by_refresh_token("token")
      %User{}

      iex> get_user_by_refresh_token!("not_valid_token")
      nil
  """
  def get_user_by_refresh_token(token) do
    query = PartialQuery.active_token_query(UserToken.refresh_token_type(), token)

    case Repo.one(query) do
      %UserToken{} = token ->
        {:ok, get_user!(token.user_id, [:access_tokens, :two_factor_tokens, :refresh_tokens])}

      _ ->
        {:error, "cannot get user from given token"}
    end
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
  def update_user(user, attrs, changeset_fun \\ :changeset)

  def update_user(%User{} = user, attrs, changeset_fun) do
    apply(User, changeset_fun, [user, attrs])
    |> Repo.update()
  end

  def update_user(user_id, attrs, changeset_fun) do
    Repo.get(User, user_id)
    |> update_user(attrs, changeset_fun)
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
      {:ok, %UserToken{}}

      iex> get_user_token("not valid token")
      ** (Ecto.NoResultsError)

  """
  def get_user_token(token) do
    with [_expired_at, valid_token] <- decode_user_token(token),
         query <- PartialQuery.get_token_query(valid_token, with_limit: true),
         %UserToken{} = token <- Repo.one(query) do
      {:ok, token}
    else
      err -> err
    end
  end

  defp validate_token(%UserToken{type: token_type} = token, type) when token_type == type do
    case DateTime.after?(token.valid_until, DateTime.utc_now(:second)) do
      true -> Kernel.is_nil(token.used_at)
      _ -> false
    end
    |> then(fn
      true -> {:ok, token}
      _ -> validate_token(nil, nil)
    end)
  end

  defp validate_token(_, _), do: {:error, "cannot get user token"}

  @doc """
  Gets a single mfa token or nil

  ## Examples

      iex> get_user_mfa_token("token")
      %UserToken{}

      iex> get_user_mfa_token("not valid token")
      ** (Ecto.NoResultsError)

  """
  def get_user_mfa_token(token_string) do
    case get_user_token(token_string) do
      {:ok, token} -> validate_token(token, UserToken.two_factor_type())
      _ -> {:error, "cannot get user token"}
    end
  end

  @doc """
  Create a single forgot password or nil

  ## Examples

    iex> create_user_forgot_password_token(user)
    %UserToken{id: id}
  """
  def create_user_forgot_password_token(%User{} = user) do
    user
    |> Repo.preload([:forgot_password_tokens])
    |> then(& &1.forgot_password_tokens)
    |> Enum.find(&Kernel.is_nil(&1.used_at))
    |> case do
      %UserToken{} = token ->
        {:ok, token}

      _ ->
        attrs = %{
          user: user,
          valid_until: DateTime.utc_now(:second) |> DateTime.shift(day: 7),
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
    case get_user_token(token) do
      {:ok, token} -> validate_token(token, UserToken.forgot_password_type())
      nil -> {:error, "token is expired or invalid"}
    end
    |> then(fn
      {:ok, token} -> do_reset_password(token, password)
      err -> err
    end)
  end

  defp do_reset_password(%{user: user} = token, password) do
    Repo.transact(fn ->
      {:ok, updated_user} = update_user(user, %{password: password})
      {:ok, token} = update_user_token(token, %{used_at: DateTime.utc_now(:second)})

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
    user
    |> Repo.preload([:access_tokens])
    |> Map.get(:access_tokens)
    |> Enum.sort(fn a, b ->
      DateTime.after?(a.valid_until, b.valid_until)
    end)
    |> do_create_access_token_with_refresh(user)
  end

  def create_user_access_token(user_id) do
    get_user!(user_id)
    |> create_user_access_token()
  end

  defp do_create_access_token_with_refresh(tokens, user) do
    token_ids = Enum.filter(tokens, &Kernel.is_nil(&1.used_at)) |> Enum.map(& &1.id)
    query = from t in UserToken, where: t.id in ^token_ids

    [_first | delete_tokens] =
      case Enum.chunk_every(tokens, 2) do
        [] -> [nil]
        rst -> rst
      end

    updates = [set: [used_at: DateTime.utc_now(:second)]]

    attrs = %{
      user: user,
      valid_until: DateTime.utc_now(:second) |> DateTime.shift(day: 7),
      type: UserToken.access_token_type()
    }

    Repo.transact(fn ->
      Repo.update_all(query, updates)

      List.flatten(delete_tokens)
      |> Enum.map(& &1.id)
      |> case do
        [] -> :ok
        lst -> Repo.delete_all(from t in UserToken, where: t.id in ^lst)
      end

      {:ok, access} =
        case create_user_token(attrs) do
          {:ok, _access} = ret ->
            Enum.map(tokens, &Munchkin.Cache.delete(&1.token))
            ret

          err ->
            err
        end

      refresh = should_generate_refresh_token?(user)

      {:ok, %{access: access, refresh: refresh}}
    end)
  end

  defp should_generate_refresh_token?(user) do
    user
    |> Repo.preload([:refresh_tokens], force: true)
    |> Map.get(:refresh_tokens, [])
    |> tap(fn tokens -> filter_unused_refresh_tokens(tokens) end)
    |> Enum.find(&Kernel.is_nil(&1.used_at))
    |> case do
      %UserToken{} = token ->
        token

      _ ->
        attrs = %{
          user: user,
          valid_until: DateTime.utc_now(:second) |> DateTime.shift(day: 7),
          type: UserToken.refresh_token_type()
        }

        {:ok, token} = create_user_token(attrs)
        token
    end
  end

  defp filter_unused_refresh_tokens(tokens) do
    Enum.reject(tokens, &Kernel.is_nil(&1.used_at))
    |> Enum.sort(fn a, b -> DateTime.after?(a, b) end)
    |> Enum.chunk_every(2)
    |> case do
      [] ->
        :ok

      [_first | []] ->
        :ok

      [_first | tokens] ->
        ids = List.flatten(tokens) |> Enum.map(& &1.id)
        Repo.delete_all(from t in UserToken, where: t.id == ^ids)
    end
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
