defmodule HorionosWeb.UserSettingsLive.Index do
  use HorionosWeb, :live_view

  import HorionosWeb.UserSettingsLive.Components.SettingsNavigation

  alias Horionos.Accounts

  require Logger

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.settings_navigation title="Account settings" active_tab={:user_profile} />

    <div class="space-y-12">
      <div class="grid gap-x-12 gap-y-6 sm:grid-cols-2">
        <div class="space-y-1">
          <div class="text-base/7 font-semibold text-gray-950 dark:text-white sm:text-sm/6">
            Change your display name
          </div>
          <div class="text-base/6 max-w-md text-gray-500 dark:text-gray-400 sm:text-sm/6">
            Your display name is how you appear to other users on Horionos.
          </div>
        </div>
        <div>
          <.simple_form for={@full_name_form} id="full_name_form" phx-submit="update_full_name">
            <.input
              field={@full_name_form[:full_name]}
              type="text"
              label="Name"
              required
              value={@current_full_name}
            />
            <:actions>
              <.button phx-disable-with="Changing...">Change Name</.button>
            </:actions>
          </.simple_form>
        </div>
      </div>
      <hr class="border-gray-100" />
      <div class="grid gap-x-12 gap-y-6 sm:grid-cols-2">
        <div class="space-y-1">
          <div class="text-base/7 font-semibold text-gray-950 dark:text-white sm:text-sm/6">
            Change your email address
          </div>
          <div class="text-base/6 max-w-md text-gray-500 dark:text-gray-400 sm:text-sm/6">
            To change your email, you'll need to confirm your current password.
          </div>
        </div>
        <div>
          <.simple_form for={@email_form} id="email_form" phx-submit="update_email">
            <.input field={@email_form[:email]} type="email" label="Email" required />
            <.input
              field={@email_form[:current_password]}
              name="current_password"
              id="current_password_for_email"
              type="password"
              label="Current password"
              value={@email_form_current_password}
              required
            />
            <:actions>
              <.button phx-disable-with="Changing...">Change Email</.button>
            </:actions>
          </.simple_form>
        </div>
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    socket
    |> push_navigate(to: ~p"/users/settings")
    |> ok()
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.build_email_changeset(user)
    name_changeset = Accounts.build_full_name_changeset(user)

    socket
    |> assign(:current_full_name, user.full_name)
    |> assign(:current_email, user.email)
    |> assign(:email_form_current_password, nil)
    |> assign(:email_form, to_form(email_changeset))
    |> assign(:full_name_form, to_form(name_changeset))
    |> ok(layout: {HorionosWeb.Layouts, :dashboard})
  end

  @impl Phoenix.LiveView
  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_email_change(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.send_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."

        socket
        |> put_flash(:info, info)
        |> assign(email_form_current_password: nil)
        |> noreply()

      {:error, changeset} ->
        socket
        |> assign(:email_form, to_form(Map.put(changeset, :action, :update)))
        |> noreply()
    end
  end

  @impl Phoenix.LiveView
  def handle_event("update_full_name", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_full_name(user, user_params) do
      {:ok, user} ->
        full_name_form =
          user
          |> Accounts.build_full_name_changeset(user_params)
          |> to_form()

        socket
        |> assign(current_user: user)
        |> assign(full_name_form: full_name_form)
        |> assign(current_full_name: user.full_name)
        |> put_flash(:info, "Name updated successfully")
        |> noreply()

      {:error, changeset} ->
        Logger.error("Failed to update full name")

        socket
        |> assign(full_name_form: to_form(changeset))
        |> noreply()
    end
  end
end
