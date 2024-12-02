defmodule HorionosWeb.LiveHelpers do
  @moduledoc """
  LiveView helper functions.
  """
  import Phoenix.Component

  alias Horionos.Memberships.Memberships

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign(:active_tab, get_active_tab(socket))
      |> assign_user_memberships()

    {:cont, socket}
  end

  defp get_active_tab(socket) do
    case socket.view do
      HorionosWeb.DashboardLive -> :home
      HorionosWeb.Organization.IndexLive -> :organization_details
      HorionosWeb.Organization.InvitationsLive -> :organization_invitations
      HorionosWeb.UserSettings.IndexLive -> :user_profile
      HorionosWeb.UserSettings.SecurityLive -> :user_security
      _ -> :other
    end
  end

  defp assign_user_memberships(%{assigns: %{current_user: user}} = socket)
       when not is_nil(user) do
    {:ok, memberships} = Memberships.list_user_memberships(user)
    assign(socket, :memberships, memberships)
  end

  defp assign_user_memberships(socket), do: socket
end
