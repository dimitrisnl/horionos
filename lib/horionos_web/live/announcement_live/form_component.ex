defmodule HorionosWeb.AnnouncementLive.FormComponent do
  use HorionosWeb, :live_component
  import HorionosWeb.LiveAuthorization

  alias Horionos.Announcements

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <header class="mx-auto mb-4 max-w-6xl border-b border-gray-100 pb-4">
        <h1 class="text-2xl/8 font-semibold text-gray-950 dark:text-white sm:text-xl/8">
          <%= @title %>
        </h1>
      </header>

      <.simple_form for={@form} id="announcement-form" phx-target={@myself} phx-submit="save">
        <.input field={@form[:title]} type="text" label="Title" />
        <.input field={@form[:body]} type="textarea" label="Body" />
        <:actions>
          <.button phx-disable-with="Saving...">
            Save Announcement
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{announcement: announcement} = assigns, socket) do
    changeset = Announcements.build_announcement_changeset(announcement)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"announcement" => params}, socket) do
    changeset =
      socket.assigns.announcement
      |> Announcements.build_announcement_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"announcement" => params}, socket) do
    save_announcement(socket, socket.assigns.action, params)
  end

  defp save_announcement(socket, :edit, params) do
    case authorize_user_action(socket, :announcement_edit) do
      :ok ->
        case Announcements.update_announcement(socket.assigns.announcement, params) do
          {:ok, announcement} ->
            notify_parent({:saved, announcement})

            {:noreply,
             socket
             |> put_flash(:info, "Announcement updated successfully")
             |> push_patch(to: socket.assigns.patch)}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign_form(socket, changeset)}
        end

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You are not authorized to update this announcement.")
         |> push_patch(to: socket.assigns.patch)}
    end
  end

  defp save_announcement(socket, :new, params) do
    case authorize_user_action(socket, :announcement_create) do
      :ok ->
        case Announcements.create_announcement(
               socket.assigns.current_organization,
               params
             ) do
          {:ok, announcement} ->
            notify_parent({:saved, announcement})

            {:noreply,
             socket
             |> put_flash(:info, "Announcement created successfully")
             |> push_patch(to: socket.assigns.patch)}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign_form(socket, changeset)}
        end

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You are not authorized to create announcements.")
         |> push_patch(to: socket.assigns.patch)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
