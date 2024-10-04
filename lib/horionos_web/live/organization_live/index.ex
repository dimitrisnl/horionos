defmodule HorionosWeb.OrganizationLive.Index do
  use HorionosWeb, :live_view

  import HorionosWeb.OrganizationLive.Components.OrganizationNavigation

  alias Horionos.Organizations

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.organization_navigation title="Settings" active_tab={:organization_details} />

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
          <.simple_form for={@form} id="organization-form" phx-submit="save">
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
            <div class="mt-1.5 max-w-xs leading-snug">
              If you want to kick a user out of the organization, please contact support.
            </div>
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
              <.local_time
                date={membership.inserted_at}
                id={"membership-inserted-#{membership.organization_id}-#{membership.user_id}"}
              />
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
            id="delete_organization_form"
            for={%{}}
            phx-submit="delete"
            data-confirm="Are you sure you want to delete the organization? This action cannot be undone."
          >
            <.button type="submit" variant="destructive" class="mt-4">
              <:left_icon>
                <.icon name="hero-trash-micro" />
              </:left_icon>
              Delete my organization <span class="font-bold"><%= @organization.title %></span>
            </.button>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    with :ok <- authorize_user_action(socket, :organization_manage_members),
         {:ok, organization} <-
           Organizations.get_organization(socket.assigns.current_organization.id),
         {:ok, memberships} <- Organizations.list_organization_memberships(organization) do
      changeset = Organizations.build_organization_changeset(organization)

      socket
      |> assign(:organization, organization)
      |> assign(:form, to_form(changeset))
      |> stream(:memberships, memberships)
      |> ok(layout: {HorionosWeb.Layouts, :dashboard})
    else
      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, "You are not authorized to access this page.")
        |> push_navigate(to: ~p"/")
        |> ok(layout: {HorionosWeb.Layouts, :dashboard})

      {:error, _} ->
        socket
        |> put_flash(:error, "Unable to load organization details.")
        |> push_navigate(to: ~p"/")
        |> ok(layout: {HorionosWeb.Layouts, :dashboard})
    end
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"organization" => organization_params}, socket) do
    case authorize_user_action(socket, :organization_edit) do
      :ok ->
        organization = socket.assigns.organization

        case Organizations.update_organization(organization, organization_params) do
          {:ok, updated_organization} ->
            socket
            |> assign(:organization, updated_organization)
            |> assign(:current_organization, updated_organization)
            |> assign(
              :form,
              to_form(Organizations.build_organization_changeset(updated_organization))
            )
            |> put_flash(:info, "Organization updated successfully")
            |> noreply()

          {:error, %Ecto.Changeset{} = changeset} ->
            socket
            |> assign(:form, to_form(changeset))
            |> noreply()
        end

      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, "You are not authorized to update this organization.")
        |> noreply()
    end
  end

  @impl Phoenix.LiveView
  def handle_event("delete", _params, socket) do
    case authorize_user_action(socket, :organization_delete) do
      :ok ->
        organization = socket.assigns.organization

        case Organizations.delete_organization(organization) do
          {:ok, _deleted_organization} ->
            socket
            |> put_flash(:info, "Organization deleted successfully.")
            |> push_navigate(to: ~p"/")
            |> noreply()

          {:error, _} ->
            socket
            |> put_flash(:error, "Failed to delete organization.")
            |> noreply()
        end

      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, "You are not authorized to delete this organization.")
        |> noreply()
    end
  end
end
