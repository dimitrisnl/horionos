defmodule HorionosWeb.Auth.UserRegistrationLive do
  use HorionosWeb, :live_view

  alias Horionos.Accounts.EmailVerification
  alias Horionos.Accounts.Schemas.User
  alias Horionos.Accounts.Users
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
          <.input field={@form[:full_name]} type="text" label="Name" required />
          <.input field={@form[:email]} type="email" label="Email" required />
          <.input field={@form[:password]} type="password" label="Password" required />

          <:actions>
            <.button phx-disable-with="Creating account..." class="w-full">Create an account</.button>
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
    changeset = Users.build_registration_changeset(%User{})

    socket
    |> assign(trigger_submit: false)
    |> assign_form(changeset)
    |> ok(layout: {HorionosWeb.Layouts, :guest}, temporary_assigns: [form: nil])
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"user" => user_params}, socket) do
    case RateLimiter.check_rate("user_registration", 10, 3_600_000) do
      {:ok} ->
        case Users.register_user(user_params) do
          {:ok, user} ->
            {:ok, _} =
              EmailVerification.send_confirmation_instructions(
                user,
                &url(~p"/users/confirm/#{&1}")
              )

            changeset = Users.build_registration_changeset(user)

            socket
            |> assign(trigger_submit: true)
            |> assign_form(changeset)
            |> noreply()

          {:error, %Ecto.Changeset{} = changeset} ->
            socket
            |> assign_form(changeset)
            |> noreply()
        end

      {:error, :rate_limit_exceeded} ->
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
