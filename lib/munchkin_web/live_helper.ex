defmodule MunchkinWeb.LiveHelper do
  def ok(socket) do
    {:ok, socket}
  end

  def halt(socket) do
    {:error, socket}
  end

  def assign_user(session, socket) do
    case MunchkinWeb.FetchCurrentUser.get_current_user(session) do
      {:ok, user} -> Phoenix.Component.assign(socket, :current_user, user)
      _ -> Phoenix.LiveView.redirect(socket, to: "/")
    end
  end

  def assign_user_id(session, socket) do
    case MunchkinWeb.FetchCurrentUser.get_current_user(session) do
      {:ok, _user} -> Phoenix.Component.assign(socket, :current_user_session, session)
      _ -> Phoenix.LiveView.redirect(socket, to: "/")
    end
  end

  def noreply(socket) do
    {:noreply, socket}
  end

  def reply(socket, message) do
    {:reply, message, socket}
  end

  def get_current_user(%{assigns: assigns} = socket) do
    Phoenix.LiveView.connected?(socket)
    |> then(fn
      true ->
        case Map.get(assigns, :current_user) do
          %Munchkin.Accounts.User{} = user ->
            {:ok, user}

          _ ->
            MunchkinWeb.FetchCurrentUser.get_current_user(assigns.current_user_session)
        end

      _ ->
        case Map.get(assigns, :current_user_session) do
          %{"_current_user" => _id} = session ->
            MunchkinWeb.FetchCurrentUser.get_current_user(session)

          _ ->
            {:ok, nil}
        end
    end)
    |> case do
      {:ok, user} -> user
      _ -> nil
    end
  end
end
