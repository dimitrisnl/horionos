defmodule HorionosWeb.UserAuthLive do
  @moduledoc """
  Provides LiveView-specific authentication and authorization functions.
  This module handles user authentication, organization assignment, and related
  mounting operations for LiveView components.
  """
  use HorionosWeb, :verified_routes

  import Phoenix.LiveView

  alias Horionos.Accounts
  alias Horionos.Orgs

  require Logger

  @doc """
  Handles mounting and authenticating the current_user in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_user` - Assigns current_user
      to socket assigns based on user_token, or nil if
      there's no user_token or no matching user.

    * `:ensure_authenticated` - Authenticates the user from the session,
      and assigns the current_user to socket assigns based
      on user_token.
      Redirects to login page if there's no logged user.

    * `:redirect_if_user_is_authenticated` - Authenticates the user from the session.
      Redirects to signed_in_path if there's a logged user.

    * `:ensure_current_org` - Assigns the current_org to socket assigns based
      on the current_org_id session. If there's no current_org_id session,
      it assigns the primary org to the current_org.

    * `:redirect_if_locked` - Redirects to the login if the user is locked.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the current_user:

      defmodule HorionosWeb.PageLive do
        use HorionosWeb, :live_view

        on_mount {HorionosWeb.UserAuthLive, :mount_current_user}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{HorionosWeb.UserAuthLive, :ensure_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """

  # Mounts the current user to the socket assigns.
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  # Ensures that a user is authenticated. Redirects to login if not.
  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "You must log in to access this page.")
       |> redirect(to: ~p"/users/log_in")}
    end
  end

  # Ensures that the current organization is set. Redirects to onboarding if not.
  def on_mount(:ensure_current_org, _params, session, socket) do
    socket = mount_current_org(socket, session)

    if socket.assigns.current_org do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "Please create or select an organization.")
       |> redirect(to: ~p"/onboarding")}
    end
  end

  # Redirects to signed in path if the user is already authenticated.
  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  def on_mount(:redirect_if_locked, _params, session, socket) do
    socket = mount_current_user(socket, session)
    user = socket.assigns.current_user

    if Accounts.user_locked?(user) do
      {:halt,
       socket
       |> put_flash(:error, "Your account is locked. Please contact support to unlock it.")
       |> redirect(to: ~p"/users/log_in")}
    else
      {:cont, socket}
    end
  end

  # Helper functions

  defp mount_current_user(socket, session) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      if user_token = session["user_token"] do
        Accounts.get_user_by_session_token(user_token)
      end
    end)
  end

  defp mount_current_org(socket, session) do
    Phoenix.Component.assign_new(socket, :current_org, fn ->
      user = socket.assigns.current_user
      org_id = session["current_org_id"]
      do_get_current_org(user, org_id)
    end)
  end

  defp do_get_current_org(nil, _org_id), do: nil
  defp do_get_current_org(user, nil), do: Orgs.get_user_primary_org(user)

  defp do_get_current_org(user, org_id) do
    case Orgs.get_org(user, org_id) do
      {:ok, org} -> org
      _ -> nil
    end
  end

  defp signed_in_path(_socket), do: ~p"/"
end
