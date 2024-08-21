defmodule HorionosWeb.OrgLive.Invitations do
  use HorionosWeb, :live_view

  import HorionosWeb.OrgLive.Components.OrgNavigation

  alias Horionos.Orgs
  alias Horionos.Orgs.Invitation
  alias Horionos.Orgs.MembershipRole

  @impl true
  def render(assigns) do
    ~H"""
    <.org_navigation title="Settings" active_tab={:organization_invitations} />

    <div class="space-y-12">
      <div class="grid gap-x-12 gap-y-6 sm:grid-cols-2">
        <div class="space-y-1">
          <div class="text-base/7 font-semibold text-gray-950 dark:text-white sm:text-sm/6">
            Invite a new member
          </div>
          <div class="text-base/6 max-w-md text-gray-500 dark:text-gray-400 sm:text-sm/6">
            <div class="mt-2 space-y-1">
              <ul class="list-inside list-disc">
                <li>
                  <span class="font-medium">Owner:</span>
                  Can manage organization settings, resources and billing
                </li>
                <li>
                  <span class="font-medium">Admin:</span>
                  Can manage organization settings, and resources
                </li>
                <li><span class="font-medium">Member:</span> Can view organization resources</li>
              </ul>
            </div>
          </div>
        </div>
        <div>
          <.simple_form for={@form} id="invitation_form" phx-submit="send_invitation">
            <.input field={@form[:email]} type="email" label="Email" />
            <.input
              field={@form[:role]}
              type="select"
              label="Role"
              options={Enum.map(MembershipRole.assignable(), &{String.capitalize(to_string(&1)), &1})}
            />
            <.button phx-disable-with="Sending...">Send Invitation</.button>
          </.simple_form>
        </div>
      </div>

      <hr class="border-gray-100" />
      <div class="grid gap-x-12 gap-y-6 sm:grid-cols-2">
        <div class="space-y-1">
          <div class="text-base/7 font-semibold text-gray-950 dark:text-white sm:text-sm/6">
            Invitations
          </div>
          <div class="text-base/6 max-w-md text-gray-500 dark:text-gray-400 sm:text-sm/6">
            <div class="mt-2 space-y-1">
              Accepted and declined invitations will be automatically removed after 7 days. You can cancel pending invitations at any time.
            </div>
          </div>
        </div>
        <div>
          <.table id="invitations" rows={@streams.invitations}>
            <:col :let={{_id, invitation}} label="User">
              <div class="space-y-1">
                <div><%= invitation.email %></div>
                <div class="font-normal">
                  Invited by: <span class="font-medium"><%= invitation.inviter.full_name %></span>
                </div>
              </div>
            </:col>
            <:col :let={{_id, invitation}} label="Role">
              <div class="inline-flex rounded-lg bg-gray-200 px-1.5 py-1 uppercase leading-none text-gray-900">
                <%= invitation.role %>
              </div>
            </:col>
            <:col :let={{_id, invitation}} label="Status">
              <%= if invitation.accepted_at, do: "Accepted", else: "Pending" %>
            </:col>

            <:action :let={{id, invitation}}>
              <%= if is_nil(invitation.accepted_at) do %>
                <.link
                  phx-click={
                    JS.push("cancel_invitation", value: %{id: invitation.id}) |> hide("##{id}")
                  }
                  data-confirm="Are you sure you want to cancel this invitation?"
                  class="text-rose-600"
                >
                  Cancel
                </.link>
              <% end %>
            </:action>
          </.table>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    current_org = socket.assigns.current_org
    form = to_form(Orgs.build_invitation_changeset(%Invitation{role: :member}))

    case Orgs.list_org_invitations(current_user, current_org) do
      {:ok, invitations} ->
        socket =
          socket
          |> assign(:current_org, current_org)
          |> assign(:form, form)
          |> stream(:invitations, invitations)

        {:ok, socket, layout: {HorionosWeb.Layouts, :dashboard}}

      {:error, _} ->
        socket =
          socket
          |> put_flash(:error, "You are not authorized to view this page")
          |> push_navigate(to: ~p"/")

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("send_invitation", %{"invitation" => invitation_params}, socket) do
    org = socket.assigns.current_org
    inviter = socket.assigns.current_user
    email = invitation_params["email"]
    role = String.to_existing_atom(invitation_params["role"])

    case Orgs.create_invitation(inviter, org, email, role) do
      {:ok, invitation} ->
        Orgs.send_invitation_email(invitation, &url(~p"/invitations/#{&1}/accept"))

        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent")
         |> push_navigate(to: ~p"/org/invitations")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}

      {:error, :unauthorized} ->
        form = to_form(Orgs.build_invitation_changeset(%Invitation{role: :member}))

        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, "You are not authorized to invite users to this organization")}
    end
  end

  @impl true
  def handle_event("cancel_invitation", %{"id" => invitation_id}, socket) do
    current_org = socket.assigns.current_org
    current_user = socket.assigns.current_user

    case Orgs.cancel_invitation(current_user, current_org, invitation_id) do
      {:ok, cancelled_invitation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invitation cancelled successfully")
         |> stream_delete(:invitations, cancelled_invitation)}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You are not authorized to cancel this invitation")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to cancel invitation")}
    end
  end
end
