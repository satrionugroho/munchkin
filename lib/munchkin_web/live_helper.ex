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

  def noreply(socket) do
    {:noreply, socket}
  end

  def reply(socket, message) do
    {:reply, message, socket}
  end

  def get_current_user(%{assigns: assigns} = _socket), do: Map.get(assigns, :current_user)
end
