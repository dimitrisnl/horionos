defmodule HorionosWeb.LiveHelpers do
  @moduledoc """
  LiveView helper functions.
  """
  import Phoenix.Component

  alias Horionos.Organizations

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign(:active_tab, get_active_tab(socket))
      |> assign_user_organizations()

    {:cont, socket}
  end

  defp get_active_tab(socket) do
    case socket.view do
      HorionosWeb.DashboardLive -> :home
      HorionosWeb.AnnouncementLive.Index -> :announcements
      HorionosWeb.AnnouncementLive.Show -> :announcements
      HorionosWeb.OrganizationLive.Index -> :organization_details
      HorionosWeb.OrganizationLive.Invitations -> :organization_invitations
      HorionosWeb.UserSettingsLive.Index -> :user_profile
      HorionosWeb.UserSettingsLive.Security -> :user_security
      _ -> :other
    end
  end

  defp assign_user_organizations(%{assigns: %{current_user: user}} = socket)
       when not is_nil(user) do
    organizations = Organizations.list_user_organizations(user)
    assign(socket, :organizations, organizations)
  end

  defp assign_user_organizations(socket), do: socket
end
