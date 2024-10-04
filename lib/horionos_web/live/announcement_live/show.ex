defmodule HorionosWeb.AnnouncementLive.Show do
  use HorionosWeb, :live_view
  import HorionosWeb.LiveAuthorization

  alias Horionos.Announcements

  require Logger

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    socket
    |> assign(:current_email, user.email)
    |> ok(layout: {HorionosWeb.Layouts, :dashboard})
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _, socket) do
    with :ok <- authorize_user_action(socket, :announcement_view),
         {:ok, announcement} <-
           Announcements.get_announcement(socket.assigns.current_organization, id) do
      socket
      |> assign(:page_title, page_title(socket.assigns.live_action))
      |> assign(:announcement, announcement)
      |> noreply()
    else
      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, "You are not authorized to view this announcement.")
        |> push_navigate(to: ~p"/announcements")
        |> noreply()

      {:error, :not_found} ->
        socket
        |> put_flash(:error, "Announcement not found.")
        |> push_navigate(to: ~p"/announcements")
        |> noreply()
    end
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    with :ok <- authorize_user_action(socket, :announcement_delete),
         {:ok, announcement} <-
           Announcements.get_announcement(socket.assigns.current_organization, id),
         {:ok, _deleted_announcement} <- Announcements.delete_announcement(announcement) do
      socket
      |> put_flash(:info, "Announcement deleted successfully.")
      |> push_navigate(to: ~p"/announcements")
      |> noreply()
    else
      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, "You are not authorized to delete this announcement.")
        |> push_navigate(to: ~p"/announcements")
        |> noreply()

      {:error, :not_found} ->
        socket
        |> put_flash(:error, "Announcement not found.")
        |> push_navigate(to: ~p"/announcements")
        |> noreply()

      {:error, _} ->
        socket
        |> put_flash(:error, "Failed to delete announcement. Please try again.")
        |> noreply()
    end
  end

  defp page_title(:show), do: "Show Announcement"
  defp page_title(:edit), do: "Edit Announcement"
end
