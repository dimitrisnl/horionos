defmodule HorionosWeb.OrgLive.FormComponent do
  use HorionosWeb, :live_component

  alias Horionos.Orgs

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header><%= @title %></.header>

      <.simple_form for={@form} id="org-form" phx-target={@myself} phx-submit="save">
        <.input field={@form[:title]} type="text" label="Name" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Organization</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{org: org} = assigns, socket) do
    changeset = Orgs.change_org(org)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("save", %{"org" => org_params}, socket) do
    save_org(socket, socket.assigns.action, org_params)
  end

  defp save_org(socket, :edit, org_params) do
    case Orgs.update_org(socket.assigns.current_user, socket.assigns.org, org_params) do
      {:ok, org} ->
        notify_parent({:saved, org})

        {:noreply,
         socket
         |> put_flash(:info, "Organization updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You are not authorized to update this organization.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "An unexpected error occurred. Please try again.")
         |> push_patch(to: socket.assigns.patch)}
    end
  end

  defp save_org(socket, :new, org_params) do
    case Orgs.create_org(socket.assigns.current_user, org_params) do
      {:ok, org} ->
        notify_parent({:saved, org})

        {:noreply,
         socket
         |> put_flash(:info, "Organization created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
