defmodule HorionosWeb.UserAuthLive do
  @moduledoc """
  Provides LiveView-specific authentication and authorization functions.
  This module handles user authentication, organization assignment, and related
  mounting operations for LiveView components.
  """
  use HorionosWeb, :verified_routes

  import Phoenix.LiveView

  alias Horionos.Accounts.Sessions
  alias Horionos.Accounts.Users
  alias Horionos.Memberships.Memberships
  alias Horionos.Organizations.Organizations
  alias Horionos.Organizations.Policies.OrganizationPolicy

  require Logger

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
  def on_mount(:ensure_current_organization, _params, session, socket) do
    socket = mount_current_organization(socket, session)

    if socket.assigns.current_organization do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "Please create or select an organization.")
       |> redirect(to: ~p"/onboarding")}
    end
  end

  def on_mount(:ensure_email_verified, _params, _session, socket) do
    if socket.assigns.current_user && Users.email_verified?(socket.assigns.current_user) do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "Please verify your email address.")
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

    if Users.user_locked?(user) do
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
        Sessions.get_session_user(user_token)
      end
    end)
  end

  defp mount_current_organization(socket, session) do
    Phoenix.Component.assign_new(socket, :current_organization, fn ->
      user = socket.assigns.current_user
      organization_id = session["current_organization_id"]
      do_get_current_organization(user, organization_id)
    end)
  end

  defp do_get_current_organization(nil, _organization_id), do: nil

  defp do_get_current_organization(user, nil),
    do: Memberships.get_user_primary_organization(user)

  defp do_get_current_organization(user, organization_id) do
    with {:ok, organization} <- Organizations.get_organization(organization_id),
         {:ok, user_role} <- Memberships.get_user_role(user, organization),
         {:ok} <- OrganizationPolicy.authorize(user_role, :view) do
      organization
    else
      _ -> nil
    end
  end

  defp signed_in_path(_socket), do: ~p"/"
end
