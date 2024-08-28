defmodule HorionosWeb.AnnouncementLive.Index do
  use HorionosWeb, :live_view
  use HorionosWeb.LiveAuthorization

  alias Horionos.Announcements
  alias Horionos.Announcements.Announcement

  @impl true
  def mount(_params, _session, socket) do
    case authorize_user_action(socket, :announcement_view) do
      :ok ->
        user = socket.assigns.current_user
        org = socket.assigns.current_org
        announcements = Announcements.list_announcements(org)

        socket =
          socket
          |> assign(:current_email, user.email)
          |> assign(:announcements_count, length(announcements))
          |> stream(:announcements, announcements)

        {:ok, socket, layout: {HorionosWeb.Layouts, :dashboard}}

      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, "You are not authorized to view announcements.")
         |> push_navigate(to: ~p"/"), layout: {HorionosWeb.Layouts, :dashboard}}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    case authorize_user_action(socket, :announcement_edit) do
      :ok ->
        org = socket.assigns.current_org

        case Announcements.get_announcement(org, id) do
          {:ok, announcement} ->
            socket
            |> assign(:page_title, "Edit Announcement")
            |> assign(:announcement, announcement)

          {:error, :not_found} ->
            socket
            |> put_flash(:error, "Announcement not found.")
            |> push_navigate(to: ~p"/announcements")
        end

      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, "You are not authorized to edit announcements.")
        |> push_navigate(to: ~p"/announcements")
    end
  end

  defp apply_action(socket, :new, _params) do
    case authorize_user_action(socket, :announcement_create) do
      :ok ->
        socket
        |> assign(:page_title, "New Announcement")
        |> assign(:announcement, %Announcement{})

      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, "You are not authorized to create announcements.")
        |> push_navigate(to: ~p"/announcements")
    end
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
    with :ok <- authorize_user_action(socket, :announcement_delete),
         {:ok, announcement} <- Announcements.get_announcement(socket.assigns.current_org, id),
         {:ok, _deleted_announcement} <- Announcements.delete_announcement(announcement) do
      {:noreply,
       socket
       |> stream_delete(:announcements, announcement)
       |> update(:announcements_count, &(&1 - 1))
       |> put_flash(:info, "Announcement deleted successfully.")}
    else
      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You are not authorized to delete announcements.")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Announcement not found.")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete announcement. Please try again.")}
    end
  end
end
