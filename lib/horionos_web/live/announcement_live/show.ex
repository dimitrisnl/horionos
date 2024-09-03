defmodule HorionosWeb.AnnouncementLive.Show do
  use HorionosWeb, :live_view
  import HorionosWeb.LiveAuthorization

  alias Horionos.Announcements

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:current_email, user.email)

    {:ok, socket, layout: {HorionosWeb.Layouts, :dashboard}}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    with :ok <- authorize_user_action(socket, :announcement_view),
         {:ok, announcement} <-
           Announcements.get_announcement(socket.assigns.current_organization, id) do
      {:noreply,
       socket
       |> assign(:page_title, page_title(socket.assigns.live_action))
       |> assign(:announcement, announcement)}
    else
      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You are not authorized to view this announcement.")
         |> push_navigate(to: ~p"/announcements")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Announcement not found.")
         |> push_navigate(to: ~p"/announcements")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    with :ok <- authorize_user_action(socket, :announcement_delete),
         {:ok, announcement} <-
           Announcements.get_announcement(socket.assigns.current_organization, id),
         {:ok, _deleted_announcement} <- Announcements.delete_announcement(announcement) do
      {:noreply,
       socket
       |> put_flash(:info, "Announcement deleted successfully.")
       |> push_navigate(to: ~p"/announcements")}
    else
      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You are not authorized to delete this announcement.")
         |> push_navigate(to: ~p"/announcements")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Announcement not found.")
         |> push_navigate(to: ~p"/announcements")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete announcement. Please try again.")}
    end
  end

  defp page_title(:show), do: "Show Announcement"
  defp page_title(:edit), do: "Edit Announcement"
end
