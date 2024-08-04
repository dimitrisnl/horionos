defmodule HorionosWeb.AnnouncementLive.Show do
  use HorionosWeb, :live_view

  alias Horionos.Announcements
  alias Horionos.Orgs

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    orgs = Orgs.list_user_orgs(user)

    socket =
      socket
      |> assign(:orgs, orgs)
      |> assign(:current_email, user.email)

    {:ok, socket, layout: {HorionosWeb.Layouts, :dashboard}}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    user = socket.assigns.current_user
    org = socket.assigns.current_org

    case Announcements.get_announcement(user, id, org.id) do
      {:ok, announcement} ->
        {:noreply,
         socket
         |> assign(:page_title, page_title(socket.assigns.live_action))
         |> assign(:announcement, announcement)}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Announcement not found.")
         |> push_navigate(to: ~p"/announcements")}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You are not authorized to view this announcement.")
         |> push_navigate(to: ~p"/announcements")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    org = socket.assigns.current_org

    case Announcements.get_announcement(user, id, org.id) do
      {:ok, announcement} ->
        case Announcements.delete_announcement(user, announcement) do
          {:ok, _deleted_announcement} ->
            {:noreply,
             socket
             |> put_flash(:info, "Announcement deleted successfully.")
             |> push_navigate(to: ~p"/announcements")}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to delete announcement. Please try again.")}
        end

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Unable to delete announcement.")
         |> push_navigate(to: ~p"/announcements")}
    end
  end

  defp page_title(:show), do: "Show Announcement"
  defp page_title(:edit), do: "Edit Announcement"
end
