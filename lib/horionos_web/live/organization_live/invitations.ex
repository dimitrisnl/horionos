defmodule HorionosWeb.OrganizationLive.Invitations do
  use HorionosWeb, :live_view

  import HorionosWeb.OrganizationLive.Components.OrganizationNavigation

  alias Horionos.Organizations
  alias Horionos.Organizations.Invitation
  alias Horionos.Organizations.MembershipRole

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.organization_navigation title="Organization invitations" active_tab={:organization_invitations} />

    <div class="space-y-12">
      <div class="grid gap-x-12 gap-y-6 sm:grid-cols-2">
        <div class="space-y-1">
          <div class="text-base/7 font-semibold text-gray-950 dark:text-white sm:text-sm/6">
            Invite a new member
          </div>
          <div class="text-base/6 max-w-md text-gray-500 dark:text-gray-400 sm:text-sm/6">
            <div class="mt-4">
              <ul class="space-y-2.5">
                <li>
                  <span class="font-medium text-gray-800">Member:</span>
                  Can view and manage organization resources.
                </li>
                <li>
                  <span class="font-medium text-gray-800">Admin:</span>
                  Can update organization settings, invite new members, and manage organization resources.
                </li>
                <li>
                  <span class="font-medium text-gray-800">Owner:</span>
                  Every organization has a single owner, who can manage billing, and delete the organization. If you wish to transfer ownership, please contact support.
                </li>
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
            Pending Invitations
          </div>
          <div class="text-base/6 max-w-md text-gray-500 dark:text-gray-400 sm:text-sm/6">
            <div class="mt-2 space-y-1">
              Invitations are pending until the recipient accepts them. You can cancel an invitation at any time.
            </div>
          </div>
        </div>
        <div>
          <.table id="invitations" rows={@streams.invitations}>
            <:col :let={{_id, invitation}} label="User">
              <div class="space-y-1">
                <div><%= invitation.email %></div>
                <div class="font-normal">
                  Invited by:
                  <span class="font-medium"><%= Invitation.inviter_name(invitation) %></span>
                </div>
              </div>
            </:col>
            <:col :let={{_id, invitation}} label="Role">
              <div class="inline-flex rounded-lg bg-gray-200 px-1.5 py-1 text-xs uppercase leading-none text-gray-900">
                <%= invitation.role %>
              </div>
            </:col>

            <:action :let={{id, invitation}}>
              <.link
                phx-click={
                  JS.push("delete_invitation", value: %{id: invitation.id}) |> hide("##{id}")
                }
                data-confirm="Are you sure you want to cancel this invitation?"
                class="text-rose-600"
              >
                Cancel
              </.link>
            </:action>
          </.table>
        </div>
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    current_organization = socket.assigns.current_organization
    form = to_form(Organizations.build_invitation_changeset(%Invitation{role: :member}))

    with :ok <- authorize_user_action(socket, :organization_invite_members),
         {:ok, invitations} <-
           Organizations.list_pending_organization_invitations(current_organization) do
      socket
      |> assign(:current_organization, current_organization)
      |> assign(:form, form)
      |> stream(:invitations, invitations)
      |> ok(layout: {HorionosWeb.Layouts, :dashboard})
    else
      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, "You are not authorized to view this page")
        |> push_navigate(to: ~p"/")
        |> ok()
    end
  end

  @impl Phoenix.LiveView
  def handle_event("send_invitation", %{"invitation" => invitation_params}, socket) do
    case authorize_user_action(socket, :organization_invite_members) do
      :ok ->
        organization = socket.assigns.current_organization
        inviter = socket.assigns.current_user
        email = invitation_params["email"]
        role = String.to_existing_atom(invitation_params["role"])

        case Organizations.create_invitation(inviter, organization, email, role) do
          {:ok, %{invitation: invitation, token: token}} ->
            accept_url = url(socket, ~p"/invitations/#{token}/accept")
            Organizations.send_invitation_email(invitation, accept_url)

            socket
            |> put_flash(:info, "Invitation sent")
            |> push_navigate(to: ~p"/organization/invitations")
            |> noreply()

          {:error, :already_member} ->
            socket
            |> put_flash(:error, "User is already a member of this organization")
            |> noreply()

          {:error, :invalid_role} ->
            socket
            |> put_flash(:error, "Invalid role selected")
            |> noreply()

          {:error, %Ecto.Changeset{} = changeset} ->
            socket
            |> assign(:form, to_form(changeset))
            |> noreply()
        end

      {:error, :unauthorized} ->
        form = to_form(Organizations.build_invitation_changeset(%Invitation{role: :member}))

        socket
        |> assign(:form, form)
        |> put_flash(:error, "You are not authorized to invite users to this organization")
        |> noreply()
    end
  end

  @impl Phoenix.LiveView
  def handle_event("delete_invitation", %{"id" => invitation_id}, socket) do
    case authorize_user_action(socket, :organization_invite_members) do
      :ok ->
        case Organizations.delete_invitation(invitation_id) do
          {:ok, cancelled_invitation} ->
            socket
            |> put_flash(:info, "Invitation cancelled successfully")
            |> stream_delete(:invitations, cancelled_invitation)
            |> noreply()

          {:error, _changeset} ->
            socket
            |> put_flash(:error, "Failed to cancel invitation")
            |> noreply()
        end

      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, "You are not authorized to cancel this invitation")
        |> noreply()
    end
  end
end
