defmodule HorionosWeb.OrgLive.Index do
  use HorionosWeb, :live_view

  import HorionosWeb.OrgLive.Components.OrgNavigation

  alias Horionos.Orgs

  @impl true
  def render(assigns) do
    ~H"""
    <.org_navigation title="Settings" active_tab={:organization_details} />

    <div class="space-y-12">
      <div class="grid gap-x-12 gap-y-6 sm:grid-cols-2">
        <div class="space-y-1">
          <div class="text-base/7 font-semibold text-gray-950 dark:text-white sm:text-sm/6">
            Edit Organization
          </div>
          <div class="text-base/6 max-w-md text-gray-500 dark:text-gray-400 sm:text-sm/6">
            Update the organization details.
          </div>
        </div>
        <div>
          <.simple_form for={@form} id="org-form" phx-submit="save">
            <.input field={@form[:title]} type="text" label="Name" />
            <:actions>
              <.button phx-disable-with="Saving...">Change Name</.button>
            </:actions>
          </.simple_form>
        </div>
      </div>

      <hr class="border-gray-100" />

      <div class="grid gap-x-12 gap-y-6 sm:grid-cols-2">
        <div class="space-y-1">
          <div class="text-base/7 font-semibold text-gray-950 dark:text-white sm:text-sm/6">
            Users
          </div>
          <div class="text-base/6 max-w-md text-gray-500 dark:text-gray-400 sm:text-sm/6">
            Manage the users in your organization.
          </div>
        </div>
        <div>
          <.table id="users" rows={@streams.memberships}>
            <:col :let={{_id, membership}} label="User">
              <div>
                <div><%= membership.user.full_name %></div>
                <div class="font-normal"><%= membership.user.email %></div>
              </div>
            </:col>
            <:col :let={{_id, membership}} label="Role">
              <div class="inline-flex rounded-lg bg-gray-200 px-1.5 py-1 uppercase leading-none text-gray-900">
                <%= membership.role %>
              </div>
            </:col>
            <:col :let={{_id, membership}} label="Joined">
              <.local_time date={membership.inserted_at} id={"membership-inserted-#{membership.id}"} />
            </:col>
          </.table>
        </div>
      </div>

      <hr class="border-gray-100" />

      <div class="grid gap-x-12 gap-y-6 sm:grid-cols-2">
        <div class="space-y-1">
          <div class="text-base/7 font-semibold text-gray-950 dark:text-white sm:text-sm/6">
            Danger Zone
          </div>
          <div class="text-base/6 max-w-md text-gray-500 dark:text-gray-400 sm:text-sm/6">
            Actions that are irreversible. Be careful.
          </div>
        </div>
        <div>
          <.form
            id="delete_org_form"
            for={%{}}
            phx-submit="delete"
            data-confirm="Are you sure you want to delete the organization? This action cannot be undone."
          >
            <.button type="submit" variant="destructive" class="mt-4">
              <:left_icon>
                <.icon name="hero-trash-micro" />
              </:left_icon>
              Delete my organization <span class="font-bold"><%= @org.title %></span>
            </.button>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    current_org = socket.assigns.current_org

    case Orgs.get_org(current_user, current_org.id) do
      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, "You are not authorized to access this page.")
         |> push_navigate(to: ~p"/"), layout: {HorionosWeb.Layouts, :dashboard}}

      {:ok, org} ->
        case Orgs.list_org_memberships(current_user, org) do
          {:ok, memberships} ->
            changeset = Orgs.build_org_changeset(org)

            {:ok,
             socket
             |> assign(:org, org)
             |> assign(:form, to_form(changeset))
             |> stream(:memberships, memberships), layout: {HorionosWeb.Layouts, :dashboard}}

          {:error, :unauthorized} ->
            {:ok,
             socket
             |> put_flash(:error, "You are not authorized to view this organization.")
             |> push_navigate(to: ~p"/"), layout: {HorionosWeb.Layouts, :dashboard}}
        end
    end
  end

  @impl true
  def handle_event("save", %{"org" => org_params}, socket) do
    user = socket.assigns.current_user
    org = socket.assigns.org

    case Orgs.update_org(user, org, org_params) do
      {:ok, updated_org} ->
        {:noreply,
         socket
         |> assign(:org, updated_org)
         |> assign(:form, to_form(Orgs.build_org_changeset(updated_org)))
         |> put_flash(:info, "Organization updated successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You are not authorized to update this organization.")}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    org = socket.assigns.org
    user = socket.assigns.current_user

    case Orgs.delete_org(user, org) do
      {:ok, _deleted_org} ->
        {:noreply,
         socket
         |> put_flash(:info, "Organization deleted successfully.")
         |> push_navigate(to: ~p"/")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete organization.")}
    end
  end
end
