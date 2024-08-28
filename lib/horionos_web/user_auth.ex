defmodule HorionosWeb.UserAuth do
  @moduledoc """
  User authentication functions for controllers and plugs.
  """
  use HorionosWeb, :verified_routes

  require Logger

  import Plug.Conn
  import Phoenix.Controller

  alias Horionos.Accounts
  alias Horionos.Authorization
  alias Horionos.Orgs

  # Constants
  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in SessionToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_horionos_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  # User Session Management
  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in_user(conn, user, params \\ %{}, device_info \\ %{}) do
    token = Accounts.create_session_token(user, device_info)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect_based_on_user_state(user, user_return_to)
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.revoke_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      HorionosWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
  end

  # Plugs
  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Accounts.get_user_from_session_token(user_token)
    assign(conn, :current_user, user)
  end

  @doc """
  Fetches the current organization for the user.
  """
  def fetch_current_org(conn, _opts) do
    with %{assigns: %{current_user: user}} when not is_nil(user) <- conn,
         org_id when not is_nil(org_id) <- get_session(conn, :current_org_id),
         {:ok, org} <- Orgs.get_org(org_id),
         :ok <- Authorization.authorize(user, org, :org_view) do
      assign_current_org(conn, org)
    else
      %{assigns: %{current_user: nil}} -> conn
      _ -> handle_org_not_found(conn, conn.assigns.current_user)
    end
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash_if_not_root()
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log_in")
      |> halt()
    end
  end

  @doc """
  Ensures the user has an associated organization.
  """
  def require_org(conn, _opts) do
    if conn.assigns[:current_org] do
      conn
    else
      conn
      |> redirect(to: ~p"/onboarding")
      |> halt()
    end
  end

  # Private Helper Functions
  defp redirect_based_on_user_state(conn, user, user_return_to) do
    case Orgs.get_user_primary_org(user) do
      nil ->
        conn
        |> redirect(to: ~p"/onboarding")

      org ->
        conn
        |> put_session(:current_org_id, org.id)
        |> redirect(to: user_return_to || signed_in_path(conn))
    end
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp assign_current_org(conn, org) do
    conn
    |> assign(:current_org, org)
    |> put_session(:current_org_id, org.id)
  end

  defp handle_org_not_found(conn, user) do
    case Orgs.get_user_primary_org(user) do
      nil ->
        conn
        |> assign(:current_org, nil)
        |> delete_session(:current_org_id)

      org ->
        assign_current_org(conn, org)
    end
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
      end
    end
  end

  def require_email_verified(conn, _opts) do
    if Accounts.email_verified_or_pending?(conn.assigns.current_user) do
      conn
    else
      conn
      |> log_out_user()
      |> put_flash(
        :error,
        "Your email address needs to be verified. Please check your inbox for the verification email."
      )
      |> redirect(to: ~p"/users/log_in")
      |> halt()
    end
  end

  def require_unlocked_account(conn, _opts) do
    if Accounts.user_locked?(conn.assigns.current_user) do
      conn
      |> clear_session()
      |> put_flash(
        :error,
        "Your account is locked. Please contact support to unlock it."
      )
      |> redirect(to: ~p"/users/log_in")
      |> halt()
    else
      conn
    end
  end

  defp put_flash_if_not_root(conn) do
    case current_path(conn) === "/" do
      true -> conn
      false -> conn |> put_flash(:error, "You must log in to access this page.")
    end
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: ~p"/"
end
