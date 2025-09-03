defmodule MunchkinWeb.Router do
  use MunchkinWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MunchkinWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :restricted_api do
    plug :accepts, ["json"]
    plug MunchkinWeb.FetchCurrentUser
  end

  scope "/", MunchkinWeb do
    pipe_through :browser

    get "/", PageController, :home

    get "/accounts/verification", EmailVerificationController, :index
  end

  # Other scopes may use custom stacks.
  scope "/api", MunchkinWeb.API do
    pipe_through :api

    scope "/v1", V1 do
      post "/registrations", RegistrationController, :create
      post "/sessions", SessionController, :create

      get "/forgot_password", SessionController, :forgot_password_request
      post "/forgot_password", SessionController, :forgot_password
    end
  end

  scope "/api", MunchkinWeb.API do
    pipe_through :restricted_api

    scope "/v1", V1 do
      resources "/accounts", UserController, only: [:index, :create]
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:munchkin, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MunchkinWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
