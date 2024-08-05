defmodule HorionosWeb.LiveHelpers do
  import Phoenix.Component

  alias Horionos.Orgs

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign(:active_tab, get_active_tab(socket))
      |> assign_user_orgs()

    {:cont, socket}
  end

  defp get_active_tab(socket) do
    case socket.view do
      HorionosWeb.DashboardLive -> :home
      HorionosWeb.AnnouncementLive.Index -> :announcements
      HorionosWeb.AnnouncementLive.Show -> :announcements
      HorionosWeb.OrgLive.Index -> :organizations
      HorionosWeb.OrgLive.Show -> :organizations
      _ -> :other
    end
  end

  defp assign_user_orgs(%{assigns: %{current_user: user}} = socket) when not is_nil(user) do
    orgs = Orgs.list_user_orgs(user)
    assign(socket, :orgs, orgs)
  end

  defp assign_user_orgs(socket), do: socket
end
