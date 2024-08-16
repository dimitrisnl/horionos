defmodule HorionosWeb.AnnouncementLive.Index do
  use HorionosWeb, :live_view

  alias Horionos.Announcements
  alias Horionos.Announcements.Announcement

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    org = socket.assigns.current_org

    with {:ok, announcements} <- Announcements.list_announcements(user, org) do
      socket =
        socket
        |> assign(:current_email, user.email)
        |> assign(:announcements_count, length(announcements))
        |> stream(:announcements, announcements)

      {:ok, socket, layout: {HorionosWeb.Layouts, :dashboard}}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    user = socket.assigns.current_user
    org = socket.assigns.current_org

    case Announcements.get_announcement(user, org, id) do
      {:ok, announcement} ->
        socket
        |> assign(:page_title, "Edit Announcement")
        |> assign(:announcement, announcement)

      {:error, :not_found} ->
        socket
        |> put_flash(:error, "Announcement not found.")
        |> push_navigate(to: ~p"/announcements")

      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, "You are not authorized to edit this announcement.")
        |> push_navigate(to: ~p"/announcements")
    end
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Announcement")
    |> assign(:announcement, %Announcement{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Announcements")
    |> assign(:announcement, nil)
  end

  @impl true
  def handle_info({HorionosWeb.AnnouncementLive.FormComponent, {:saved, announcement}}, socket) do
    {:noreply,
     socket
     |> stream_insert(:announcements, announcement)
     |> update(:announcements_count, &(&1 + 1))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    org = socket.assigns.current_org

    case Announcements.get_announcement(user, org, id) do
      {:ok, announcement} ->
        case Announcements.delete_announcement(user, announcement) do
          {:ok, _deleted_announcement} ->
            {:noreply,
             socket
             |> stream_delete(:announcements, announcement)
             |> update(:announcements_count, &(&1 - 1))
             |> put_flash(:info, "Announcement deleted successfully.")}

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
end
