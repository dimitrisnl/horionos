defmodule HorionosWeb.UserSettingsLive.Security do
  use HorionosWeb, :live_view

  alias Horionos.Accounts
  require Logger

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Account Security
      <:actions>
        <nav class="flex flex-row space-x-4 space-y-0">
          <a
            href={~p"/users/settings"}
            class={[
              "rounded-md px-3 py-2 text-sm font-medium",
              "text-gray-500 hover:text-gray-700",
              @active_tab == :user_profile && "bg-gray-100 text-gray-900"
            ]}
          >
            Profile
          </a>
          <a
            href={~p"/users/settings/security"}
            class={[
              "rounded-md px-3 py-2 text-sm font-medium",
              "text-gray-500 hover:text-gray-700",
              @active_tab == :user_security && "bg-gray-100 text-gray-900"
            ]}
          >
            Security
          </a>
        </nav>
      </:actions>
    </.header>

    <div class="space-y-12">
      <div class="grid gap-x-12 gap-y-6 sm:grid-cols-2">
        <div class="space-y-1">
          <div class="text-base/7 font-semibold text-gray-950 dark:text-white sm:text-sm/6">
            Change your password
          </div>
          <div class="text-base/6 text-gray-500 dark:text-gray-400 sm:text-sm/6">
            To change your password, you'll need to confirm your current one.
            <br />After the change, we'll clear all your sessions for security reasons.
          </div>
        </div>
        <div>
          <.simple_form
            for={@password_form}
            id="password_form"
            action={~p"/users/log_in?_action=password_updated"}
            method="post"
            phx-submit="update_password"
            phx-trigger-action={@trigger_submit}
          >
            <.input field={@password_form[:password]} type="password" label="New password" required />

            <.input
              field={@password_form[:current_password]}
              name="current_password"
              type="password"
              label="Current password"
              id="current_password_for_password"
              value={@current_password}
              required
            />
            <input
              name={@password_form[:email].name}
              type="hidden"
              id="hidden_user_email"
              value={@current_email}
            />
            <:actions>
              <.button phx-disable-with="Changing...">Change Password</.button>
            </:actions>
          </.simple_form>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    password_changeset = Accounts.change_user_password(user)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket, layout: {HorionosWeb.Layouts, :dashboard}}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end
end
