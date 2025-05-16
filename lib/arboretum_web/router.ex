defmodule ArboretumWeb.Router do
  use ArboretumWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ArboretumWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ArboretumWeb do
    pipe_through :browser

    get "/", PageController, :home
    
    # Agent routes
    live "/agents", AgentLive.Index, :index
    live "/agents/new", AgentLive.Index, :new
    live "/agents/:id", AgentLive.Show, :show
    live "/agents/:id/edit", AgentLive.Show, :edit
    
    # Batch routes
    live "/batches", BatchLive.Index, :index
    live "/batches/:id", BatchLive.Show, :show
    live "/batches/new", BatchLive.New, :new
  end

  # Other scopes may use custom stacks.
  # scope "/api", ArboretumWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:arboretum, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ArboretumWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
