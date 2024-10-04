defmodule HorionosWeb.AnnouncementLive.Index do
  use HorionosWeb, :live_view

  alias Horionos.Announcements
  alias Horionos.Announcements.Announcement

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    case authorize_user_action(socket, :announcement_view) do
      :ok ->
        user = socket.assigns.current_user
        organization = socket.assigns.current_organization
        announcements = Announcements.list_announcements(organization)

        socket
        |> assign(:current_email, user.email)
        |> assign(:announcements_count, length(announcements))
        |> stream(:announcements, announcements)
        |> ok(layout: {HorionosWeb.Layouts, :dashboard})

      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, "You are not authorized to view announcements.")
        |> push_navigate(to: ~p"/")
        |> ok(layout: {HorionosWeb.Layouts, :dashboard})
    end
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    socket
    |> apply_action(socket.assigns.live_action, params)
    |> noreply()
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    case authorize_user_action(socket, :announcement_edit) do
      :ok ->
        organization = socket.assigns.current_organization

        case Announcements.get_announcement(organization, id) do
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

  @impl Phoenix.LiveView
  def handle_info({HorionosWeb.AnnouncementLive.FormComponent, {:saved, announcement}}, socket) do
    socket
    |> stream_insert(:announcements, announcement)
    |> update(:announcements_count, &(&1 + 1))
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    with :ok <- authorize_user_action(socket, :announcement_delete),
         {:ok, announcement} <-
           Announcements.get_announcement(socket.assigns.current_organization, id),
         {:ok, _deleted_announcement} <- Announcements.delete_announcement(announcement) do
      socket
      |> stream_delete(:announcements, announcement)
      |> update(:announcements_count, &(&1 - 1))
      |> put_flash(:info, "Announcement deleted successfully.")
      |> noreply()
    else
      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, "You are not authorized to delete announcements.")
        |> noreply()

      {:error, :not_found} ->
        socket
        |> put_flash(:error, "Announcement not found.")
        |> noreply()

      {:error, _} ->
        socket
        |> put_flash(:error, "Failed to delete announcement. Please try again.")
        |> noreply()
    end
  end
end
