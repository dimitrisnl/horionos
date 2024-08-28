defmodule HorionosWeb.InvitationLive.Accept do
  use HorionosWeb, :live_view

  alias Horionos.Organizations

  @impl true
  def render(assigns) do
    ~H"""
    <.guest_view title="Accept Invitation" subtitle={"Join #{@invitation.organization.title}"}>
      <.card>
        <.simple_form
          for={@form}
          id="invitation_form"
          phx-submit="accept_invitation"
          phx-trigger-action={@trigger_submit}
          action={~p"/users/log_in?_action=invitation_accepted"}
          method="post"
        >
          <%= if @current_user do %>
            <.input field={@form[:email]} type="email" label="Email" readonly hidden required />
          <% else %>
            <.input field={@form[:full_name]} type="text" label="Full Name" required />
            <.input field={@form[:password]} type="password" label="Password" required />
            <.input field={@form[:email]} type="email" label="Email" required hidden readonly />
          <% end %>
          <:actions>
            <.button phx-disable-with="Accepting..." class="w-full">
              Accept invitation
              <:right_icon>
                <.icon name="hero-arrow-right-micro" />
              </:right_icon>
            </.button>
          </:actions>
        </.simple_form>
      </.card>
    </.guest_view>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Organizations.get_pending_invitation_by_token(token) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Invitation not found or already accepted")
         |> redirect(to: "/users/log_in")}

      invitation ->
        current_user = socket.assigns[:current_user]

        if can_accept_invitation?(current_user, invitation) do
          form = to_form(invitation_form(invitation, current_user), as: "user")

          {:ok,
           socket
           |> assign(:invitation, invitation)
           |> assign(:form, form)
           |> assign(:trigger_submit, false),
           temporary_assigns: [form: form], layout: {HorionosWeb.Layouts, :guest}}
        else
          {:ok,
           socket
           |> put_flash(:error, "Invitation not found or already accepted")
           |> redirect(to: ~p"/")}
        end
    end
  end

  @impl true
  def handle_event("accept_invitation", %{"user" => user_params}, socket) do
    %{invitation: invitation, current_user: current_user} = socket.assigns

    case Organizations.accept_invitation(invitation, user_params) do
      {:ok, %{user: _user, invitation: _invitation, membership: _membership}} ->
        {:noreply,
         socket
         |> assign(trigger_submit: true)
         |> assign(form: to_form(user_params, as: "user"))}

      {:error, :already_accepted} ->
        {:noreply,
         socket
         |> put_flash(:error, "This invitation has already been accepted")
         |> redirect(to: "/")}

      {:error, _failed_operation, {:user_creation_failed, error_details}, _changes_so_far} ->
        error_messages = format_error_messages(error_details)

        {:noreply,
         socket
         |> put_flash(:error, "Error accepting invitation: #{error_messages}")
         |> assign(form: to_form(invitation_form(invitation, current_user), as: "user"))}

      {:error, failed_operation, _failed_value, _changes_so_far} ->
        error_message = user_friendly_error_message(failed_operation)

        {:noreply,
         socket
         |> put_flash(:error, error_message)
         |> assign(form: to_form(invitation_form(invitation, current_user), as: "user"))}
    end
  end

  defp invitation_form(invitation, current_user) do
    %{
      "email" => (current_user && current_user.email) || invitation.email,
      "full_name" => (current_user && current_user.full_name) || ""
    }
  end

  defp can_accept_invitation?(nil, _invitation), do: true

  defp can_accept_invitation?(current_user, invitation) do
    current_user.email == invitation.email
  end

  defp format_error_messages(error_details) do
    Enum.map_join(error_details, ". ", fn {field, errors} ->
      "#{Phoenix.Naming.humanize(field)} #{Enum.join(errors, ", ")}"
    end)
  end

  defp user_friendly_error_message(failed_operation) do
    case failed_operation do
      :user -> "Error creating user account. Please try again."
      :invitation -> "Error processing invitation. Please try again."
      :membership -> "Error adding you to the organization. Please contact support."
      _ -> "An unexpected error occurred. Please try again or contact support."
    end
  end
end
