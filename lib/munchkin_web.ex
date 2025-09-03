defmodule MunchkinWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use MunchkinWeb, :controller
      use MunchkinWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      use Gettext, backend: MunchkinWeb.Gettext

      import Plug.Conn
      import MunchkinWeb.FetchCurrentUser, only: [get_current_user: 1]

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # Translation
      use Gettext, backend: MunchkinWeb.Gettext

      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components
      import MunchkinWeb.CoreComponents

      # Common modules used in templates
      alias Phoenix.LiveView.JS
      alias MunchkinWeb.Layouts

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: MunchkinWeb.Endpoint,
        router: MunchkinWeb.Router,
        statics: MunchkinWeb.static_paths()
    end
  end

  def mailer(opts) do
    view = Keyword.get(opts, :view)
    engine = Keyword.get(opts, :engine)

    quote bind_quoted: [view: view, engine: engine] do
      use Gettext, backend: MunchkinWeb.Gettext

      import Swoosh.Email

      def render_body(email, template, assigns \\ %{}) do
        title = Map.get(assigns, :title, "")
        message =
          Phoenix.Template.render_to_string(unquote(view), to_string(template), "html", assigns)

        rendered =
          Phoenix.Template.render_to_string(unquote(view), "email", "html",
            inner_content: message,
            title: title
          )

        email
        |> html_body(rendered)
      end

      def deliver(email), do: unquote(engine).deliver(email)

      def sender, do: unquote(engine).sender()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  defmacro __using__(opts) do
    {which, params} = Keyword.pop_first(opts, :type)
    apply(__MODULE__, which, [params])
  end
end
