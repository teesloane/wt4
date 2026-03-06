defmodule WeaktyWeb.Router do
  use WeaktyWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :graphql do
    plug :load_from_bearer
    plug :set_actor, :user
    plug AshGraphql.Plug
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WeaktyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  scope "/", WeaktyWeb do
    pipe_through :browser

    # RSS feed
    get "/posts/rss", RssController, :posts

    ash_authentication_live_session :authenticated_routes do
      live "/now", UpdateLive.Index, :index
      live "/now/:slug", UpdateLive.Show, :show
      live "/areas", AreaLive.Index, :index
      live "/areas/:slug", AreaLive.Show, :show
      live "/links", LinkLive.Index, :index
      live "/links/:slug", LinkLive.Show, :show
      live "/posts", PostLive.Index, :index
      live "/posts/:slug", PostLive.Show, :show
      live "/projects", ProjectLive.Index, :index
      live "/projects/:slug", ProjectLive.Show, :show
      live "/media-logs", MediaLogLive.Index, :index
      # live "/media-logs/:slug", MediaLogLive.Show, :show
      live "/quotes", QuoteLive.Index, :index
      live "/til", TilLive.Index, :index
      live "/til/:slug", TilLive.Show, :show
      # in each liveview, add one of the following at the top of the module:
      #
      # If an authenticated user must be present:
      # on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}
      #
      # If an authenticated user *may* be present:
      # on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}
      #
      # If an authenticated user must *not* be present:
      # on_mount {WeaktyWeb.LiveUserAuth, :live_no_user}
    end
  end

  scope "/admin", WeaktyWeb do
    pipe_through :browser

    ash_authentication_live_session :admin_routes,
      on_mount: [{WeaktyWeb.LiveUserAuth, :live_user_required}] do
      live "/", AdminLive.Dashboard, :index
      live "/posts", AdminLive.Posts.Index, :index
      live "/posts/new", AdminLive.Posts.Form, :new
      live "/posts/:id/edit", AdminLive.Posts.Form, :edit
      live "/projects", AdminLive.Projects.Index, :index
      live "/projects/new", AdminLive.Projects.Form, :new
      live "/projects/:id/edit", AdminLive.Projects.Form, :edit
      live "/links", AdminLive.Links.Index, :index
      live "/links/new", LinkLive.Form, :new
      live "/links/:id/edit", LinkLive.Form, :edit
      live "/media-logs", AdminLive.MediaLogs.Index, :index
      live "/media-logs/new", MediaLogLive.Form, :new
      live "/media-logs/:id/edit", MediaLogLive.Form, :edit
      live "/quotes", AdminLive.Quotes.Index, :index
      live "/quotes/new", QuoteLive.Form, :new
      live "/quotes/:id/edit", QuoteLive.Form, :edit
      live "/til", AdminLive.Tils.Index, :index
      live "/til/new", TilLive.Form, :new
      live "/til/:id/edit", TilLive.Form, :edit
      live "/tags", AdminLive.Tags.Index, :index
      live "/entities", AdminLive.Entities.Index, :index
      live "/jobs", AdminLive.Jobs.Index, :index
    end
  end

  scope "/gql" do
    pipe_through [:graphql]

    forward "/playground", Absinthe.Plug.GraphiQL,
      schema: Module.concat(["WeaktyWeb.GraphqlSchema"]),
      socket: Module.concat(["WeaktyWeb.GraphqlSocket"]),
      interface: :simple

    forward "/", Absinthe.Plug, schema: Module.concat(["WeaktyWeb.GraphqlSchema"])
  end

  scope "/", WeaktyWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/archive", ArchiveLive.Index, :index

    auth_routes AuthController, Weakty.Accounts.User, path: "/auth"
    sign_out_route AuthController

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{WeaktyWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    WeaktyWeb.AuthOverrides,
                    Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                overrides: [
                  WeaktyWeb.AuthOverrides,
                  Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                ]

    # Remove this if you do not use the confirmation strategy
    confirm_route Weakty.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [WeaktyWeb.AuthOverrides, Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI]

    # Remove this if you do not use the magic link strategy.
    magic_sign_in_route(Weakty.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [WeaktyWeb.AuthOverrides, Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI]
    )
  end

  # Other scopes may use custom stacks.
  # scope "/api", WeaktyWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:weakty, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WeaktyWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  if Application.compile_env(:weakty, :dev_routes) do
    import AshAdmin.Router

    scope "/dev_admin" do
      pipe_through :browser

      ash_admin "/"
    end
  end
end
