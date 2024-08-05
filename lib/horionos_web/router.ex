defmodule HorionosWeb.Router do
  use HorionosWeb, :router

  import HorionosWeb.UserAuth

  alias HorionosWeb.UserAuthLive
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HorionosWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug :fetch_current_org
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:horionos, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HorionosWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ### Only for unauthenticated users
  scope "/", HorionosWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{HorionosWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      on_mount: [{UserAuthLive, :redirect_if_user_is_authenticated}] do
      live "/users/register", AuthLive.UserRegistrationLive, :new
      live "/users/log_in", AuthLive.UserLoginLive, :new
      live "/users/reset_password", AuthLive.UserForgotPasswordLive, :new
      live "/users/reset_password/:token", AuthLive.UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  # Onboarding scope. Authenticated but not onboarded users (missing org)
  scope "/", HorionosWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :onboarding,
      on_mount: [{HorionosWeb.UserAuth, :ensure_authenticated}] do
      on_mount: [{UserAuthLive, :ensure_authenticated}] do
      live "/onboarding", OnboardingLive, :onboarding
    end
  end

  ### Authenticated routes, with an Organization in scope
  scope "/", HorionosWeb do
    pipe_through [:browser, :require_authenticated_user, :require_org]

    post "/org/select", OrgSessionController, :update

    live_session :authenticated_with_org,
      on_mount: [
        {HorionosWeb.UserAuth, :ensure_authenticated},
        {HorionosWeb.UserAuth, :ensure_current_org}
        {UserAuthLive, :ensure_authenticated},
        {UserAuthLive, :ensure_current_org},
      ] do
      live "/", DashboardLive, :home
      live "/users/settings", UserSettingsLive.Index, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive.Index, :confirm_email

      live "/orgs", OrgLive.Index, :index
      live "/orgs/new", OrgLive.Index, :new
      live "/orgs/:id/edit", OrgLive.Index, :edit
      live "/orgs/:id", OrgLive.Show, :show
      live "/orgs/:id/show/edit", OrgLive.Show, :edit

      live "/announcements", AnnouncementLive.Index, :index
      live "/announcements/new", AnnouncementLive.Index, :new
      live "/announcements/:id/edit", AnnouncementLive.Index, :edit
      live "/announcements/:id", AnnouncementLive.Show, :show
      live "/announcements/:id/show/edit", AnnouncementLive.Show, :edit
    end
  end

  ### Both authenticated and unauthenticated routes
  scope "/", HorionosWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{HorionosWeb.UserAuth, :mount_current_user}] do
      on_mount: [{UserAuthLive, :mount_current_user}] do
      live "/users/confirm/:token", AuthLive.UserConfirmationLive, :edit
      live "/users/confirm", AuthLive.UserConfirmationInstructionsLive, :new
    end
  end
end
