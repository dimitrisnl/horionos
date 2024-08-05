defmodule HorionosWeb.OrgLive.Index do
  use HorionosWeb, :live_view

  alias Horionos.Orgs
  alias Horionos.Orgs.Org

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    orgs = Orgs.list_user_orgs(user)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> stream(:orgs, orgs)

    {:ok, socket, layout: {HorionosWeb.Layouts, :dashboard}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    user = socket.assigns.current_user

    case Orgs.get_org(user, id) do
      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, "You are not authorized to edit this organization.")
        |> push_navigate(to: ~p"/orgs")

      {:ok, org} ->
        socket
        |> assign(:page_title, "Edit Org")
        |> assign(:org, org)
    end
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Org")
    |> assign(:org, %Org{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing organizations")
    |> assign(:org, nil)
  end

  @impl true
  def handle_info({HorionosWeb.OrgLive.FormComponent, {:saved, org}}, socket) do
    updated_orgs = socket.assigns.orgs ++ [org]

    {:noreply, socket |> stream_insert(:orgs, org) |> assign(:orgs, updated_orgs)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case Orgs.get_org(socket.assigns.current_user, id) do
      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, "You are not authorized to delete this organization.")
        |> push_navigate(to: ~p"/orgs")

      {:ok, org} ->
        case Orgs.delete_org(socket.assigns.current_user, org) do
          {:ok, _deleted_org} ->
            {:noreply,
             socket
             |> put_flash(:info, "Organization deleted successfully")
             |> push_navigate(to: ~p"/orgs")}

          {:error, :unauthorized} ->
            {:noreply,
             socket
             |> put_flash(:error, "You are not authorized to delete this organization")
             |> push_navigate(to: ~p"/orgs")}

          {:error, _} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to delete organization. Please try again.")
             |> push_navigate(to: ~p"/orgs")}
        end
    end
  end
end
