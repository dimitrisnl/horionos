defmodule HorionosWeb.AuthLive.UserRegistrationLive do
  use HorionosWeb, :live_view

  alias Horionos.Accounts
  alias Horionos.Accounts.User
  alias Horionos.Services.RateLimiter

  require Logger

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.guest_view title="Create your account" subtitle="It's great having you here!">
      <.card>
        <.simple_form
          for={@form}
          id="registration_form"
          phx-submit="save"
          phx-trigger-action={@trigger_submit}
          action={~p"/users/log_in?_action=registered"}
          method="post"
        >
          <div class="space-y-1 rounded-lg bg-blue-50 px-2.5 py-2 text-xs leading-snug">
            <div>Registrations are temporarily disabled</div>
            <div>
              If you want to get in touch,
              <.link href="mailto:jim@horionos.com" class="text-blue-600 underline">
                you can send me an email
              </.link>
            </div>
            <div>Thank you for your understanding</div>
          </div>
          <.input field={@form[:full_name]} type="text" label="Name" required disabled />
          <.input field={@form[:email]} type="email" label="Email" required disabled />
          <.input field={@form[:password]} type="password" label="Password" required disabled />

          <:actions>
            <.button phx-disable-with="Creating account..." class="w-full" disabled>
              Create an account
            </.button>
          </:actions>
        </.simple_form>
      </.card>

      <p class="mt-10 text-center text-sm text-gray-500">
        Already having an account?
        <.link navigate={~p"/users/log_in"} class="font-semibold text-brand hover:underline">
          Log in
        </.link>
      </p>
    </.guest_view>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    changeset = Accounts.build_registration_changeset(%User{})

    socket
    |> assign(trigger_submit: false)
    |> assign_form(changeset)
    |> ok(layout: {HorionosWeb.Layouts, :guest}, temporary_assigns: [form: nil])
  end

  @impl Phoenix.LiveView
  def handle_event("save", _, socket) do
    socket
    |> put_flash(:error, "Registrations are temporarily disabled")
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_event("nosave", %{"user" => user_params}, socket) do
    case RateLimiter.check_rate("user_registration", 10, 3_600_000) do
      :ok ->
        case Accounts.register_user(user_params) do
          {:ok, user} ->
            Logger.info("New user registered: #{user.id}")

            {:ok, _} =
              Accounts.send_confirmation_instructions(
                user,
                &url(~p"/users/confirm/#{&1}")
              )

            changeset = Accounts.build_registration_changeset(user)

            socket
            |> assign(trigger_submit: true)
            |> assign_form(changeset)
            |> noreply()

          {:error, %Ecto.Changeset{} = changeset} ->
            socket
            |> assign_form(changeset)
            |> noreply()
        end

      :error ->
        Logger.warning("Rate limit exceeded for user registration")

        socket
        |> put_flash(:error, "Too many registration attempts. Please try again later.")
        |> noreply()
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
