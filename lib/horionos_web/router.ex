defmodule HorionosWeb.Router do
  use HorionosWeb, :router

  import HorionosWeb.UserAuth

  alias HorionosWeb.LiveHelpers
  alias HorionosWeb.UserAuthLive

  @root_layout {HorionosWeb.Layouts, :root}

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: @root_layout
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug :fetch_current_organization
  end

  # Development routes
  if Application.compile_env(:horionos, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HorionosWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # Public routes (unauthenticated users only)
  scope "/", HorionosWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{UserAuthLive, :redirect_if_user_is_authenticated}] do
      live "/users/register", AuthLive.UserRegistrationLive, :new
      live "/users/log_in", AuthLive.UserLoginLive, :new
      live "/users/reset_password", AuthLive.UserForgotPasswordLive, :new
      live "/users/reset_password/:token", AuthLive.UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  # Onboarding routes (authenticated but not onboarded users)
  scope "/", HorionosWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :onboarding,
      on_mount: [{UserAuthLive, :ensure_authenticated}, {UserAuthLive, :redirect_if_locked}] do
      live "/onboarding", OnboardingLive, :onboarding
    end
  end

  # Authenticated routes with organization context
  scope "/", HorionosWeb do
    pipe_through [
      :browser,
      :require_authenticated_user,
      :require_email_verified,
      :require_unlocked_account,
      :require_organization
    ]

    post "/organization/select", OrganizationSessionController, :update
    post "/users/clear_sessions", UserSessionController, :delete_other_sessions

    live_session :authenticated_with_organization,
      on_mount: [
        {UserAuthLive, :ensure_authenticated},
        {UserAuthLive, :ensure_current_organization},
        {UserAuthLive, :redirect_if_locked},
        {LiveHelpers, :default}
      ] do
      live "/", DashboardLive, :home

      # User settings
      live "/users/settings", UserSettingsLive.Index, :edit
      live "/users/settings/security", UserSettingsLive.Security, :security
      live "/users/settings/confirm_email/:token", UserSettingsLive.Index, :confirm_email

      # Organization management
      live "/organization", OrganizationLive.Index, :index
      # live "/organizations/new", OrganizationLive.Index, :new
      live "/organization/invitations", OrganizationLive.Invitations, :index

      # Invitations
      live "/invitations/new", InvitationLive.New, :new
    end
  end

  # Mixed authentication routes
  scope "/", HorionosWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :email_confirmation,
      on_mount: [{UserAuthLive, :mount_current_user}] do
      live "/users/confirm/:token", AuthLive.UserConfirmationLive, :edit
      live "/users/confirm", AuthLive.UserConfirmationInstructionsLive, :new
    end

    # New live session for invitation acceptance (both authenticated and unauthenticated users)
    live_session :invitation_acceptance,
      on_mount: [{UserAuthLive, :mount_current_user}] do
      live "/invitations/:token/accept", InvitationLive.Accept, :accept
    end
  end
end
