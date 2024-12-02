defmodule HorionosWeb.UserSettings.SecurityLive do
  use HorionosWeb, :live_view

  import HorionosWeb.UserSettings.Components.SettingsNavigation

  alias Horionos.Accounts.Sessions
  alias Horionos.Accounts.Users

  require Logger

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.settings_navigation title="Account security" active_tab={:user_security} />

    <div class="space-y-12">
      <div class="grid gap-x-12 gap-y-6 sm:grid-cols-2">
        <div class="space-y-1">
          <div class="text-base/7 font-semibold text-gray-950 dark:text-white sm:text-sm/6">
            Change your password
          </div>
          <div class="text-base/6 max-w-md text-gray-500 dark:text-gray-400 sm:text-sm/6">
            To change your password, you'll need to confirm your current one.
            <br />After the change, we'll clear all your sessions.
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
      <hr class="border-gray-100" />

      <div class="grid gap-x-12 gap-y-6 sm:grid-cols-2">
        <div class="space-y-1">
          <div class="text-base/7 font-semibold text-gray-950 dark:text-white sm:text-sm/6">
            Active sessions
          </div>
          <div class="text-base/6 max-w-md text-gray-500 dark:text-gray-400 sm:text-sm/6">
            In case you've lost your device or you're logged in from a public computer, you can log out from all other devices.
          </div>
        </div>
        <div class="space-y-6">
          <ul class="text-md space-y-3 text-gray-600">
            <%= for session_data <- @sessions do %>
              <li class={[
                "flex items-center space-x-4 overflow-hidden rounded-lg",
                (session_data.is_current && "bg-blue-100") || "bg-gray-100"
              ]}>
                <div class={[
                  "flex flex-col items-center p-3 text-xs",
                  (session_data.is_current && "bg-blue-200 text-blue-500") ||
                    "bg-gray-200 text-gray-500"
                ]}>
                  <.icon class="size-5 flex-shrink-0" name="hero-globe-alt" />
                  <div class="mt-0.5 font-semibold">
                    {(session_data.is_current && "Active") || "Other"}
                  </div>
                </div>

                <div>
                  <div class="text-sm font-medium">
                    <%= if session_data.browser && session_data.browser != "Unknown" do %>
                      {session_data.browser}
                      <%= if session_data.browser_version && session_data.browser_version != "" do %>
                        <span class="text-xs font-medium text-gray-600">
                          (version: {session_data.browser_version})
                        </span>
                      <% end %>
                    <% else %>
                      Unknown browser
                    <% end %>
                  </div>
                  <div class="text-sm font-medium">
                    <%= if session_data.device && session_data.device != "Unknown" do %>
                      on {session_data.device}
                      <%= if session_data.os && session_data.os != "Unknown" do %>
                        <span class="text-xs font-medium text-gray-600">
                          ({session_data.os})
                        </span>
                      <% end %>
                    <% else %>
                      on unknown device
                    <% end %>
                  </div>
                </div>
              </li>
            <% end %>
          </ul>
          <%= if length(@sessions)  > 1 do %>
            <div class="max-w-md space-y-2 text-sm text-gray-700">
              <p>
                <span class="font-medium">Note:</span>
                These fields are based on the information provided by the browser and may not be accurate. Specifically, Apple devices have stopped reporting recent versions to avoid device fingerprinting.
              </p>
              <p class="font-medium">
                If you don't recognize a session, it's advised to clear the sessions and change your password. Contact us for support.
              </p>
            </div>
            <.form
              id="clear_sessions_form"
              for={@clear_sessions_form}
              action={~p"/users/clear_sessions"}
              method="post"
              phx-submit="clear_sessions"
              phx-trigger-action={@trigger_clear_sessions}
              data-confirm="Are you sure you want to log out of all other sessions? This action cannot be undone."
            >
              <.button variant="destructive" type="submit">
                Log out of all other sessions
              </.button>
            </.form>
          <% else %>
            <p class="max-w-md space-y-2 text-sm text-gray-700">
              <span class="font-medium">No other sessions found.</span>
              Any new session will be listed here.
            </p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    user = socket.assigns.current_user
    password_changeset = Users.build_password_changeset(user, %{})
    user_token = session["user_token"]

    sessions = Sessions.list_sessions(user, user_token)

    socket
    |> assign(:current_password, nil)
    |> assign(:current_email, user.email)
    |> assign(:sessions, sessions)
    |> assign(:password_form, to_form(password_changeset))
    |> assign(:clear_sessions_form, to_form(%{}))
    |> assign(:trigger_submit, false)
    |> assign(:trigger_clear_sessions, false)
    |> ok(layout: {HorionosWeb.Layouts, :dashboard})
  end

  @impl Phoenix.LiveView
  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Users.update_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Users.build_password_changeset(user_params)
          |> to_form()

        socket
        |> assign(password_form: password_form)
        |> assign(trigger_submit: true)
        |> noreply()

      {:error, changeset} ->
        socket
        |> assign(password_form: to_form(changeset))
        |> noreply()
    end
  end

  @impl Phoenix.LiveView
  def handle_event("clear_sessions", _params, socket) do
    socket
    |> assign(trigger_clear_sessions: true)
    |> assign(clear_sessions_form: to_form(%{}))
    |> noreply()
  end
end
