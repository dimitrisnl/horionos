defmodule HorionosWeb.OrgLive.Show do
  use HorionosWeb, :live_view

  alias Horionos.Orgs

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:current_email, user.email)

    {
      :ok,
      socket,
      layout: {HorionosWeb.Layouts, :dashboard}
    }
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    user = socket.assigns.current_user

    case Orgs.get_org(user, id) do
      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "Organization not found.")
         |> push_navigate(to: ~p"/orgs")}

      {:ok, org} ->
        {:noreply,
         socket
         |> assign(:page_title, page_title(socket.assigns.live_action))
         |> assign(:org, org)}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case Orgs.get_org(user, id) do
      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "Unable to delete organization.")
         |> push_navigate(to: ~p"/orgs")}

      {:ok, org} ->
        case Orgs.delete_org(user, org) do
          {:ok, _deleted_org} ->
            {:noreply,
             socket
             |> put_flash(:info, "Organization deleted successfully.")
             |> push_navigate(to: ~p"/orgs")}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to delete organization. Please try again.")}
        end
    end
  end

  defp page_title(:show), do: "Show Org"
  defp page_title(:edit), do: "Edit Org"
end
