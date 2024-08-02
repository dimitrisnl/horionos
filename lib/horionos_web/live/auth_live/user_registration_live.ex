defmodule HorionosWeb.AuthLive.UserRegistrationLive do
  use HorionosWeb, :live_view
  require Logger

  alias Horionos.Accounts
  alias Horionos.Accounts.User
  alias Horionos.Services.RateLimiter

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

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(trigger_submit: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil], layout: {HorionosWeb.Layouts, :guest}}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case RateLimiter.check_rate("user_registration", 10, 3_600_000) do
      :ok ->
        case Accounts.register_user(user_params) do
          {:ok, user} ->
            Logger.info("New user registered: #{user.id}")

            {:ok, _} =
              Accounts.deliver_user_confirmation_instructions(
                user,
                &url(~p"/users/confirm/#{&1}")
              )

            changeset = Accounts.change_user_registration(user)
            {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, socket |> assign_form(changeset)}
        end

      :error ->
        Logger.warning("Rate limit exceeded for user registration")

        {:noreply,
         socket |> put_flash(:error, "Too many registration attempts. Please try again later.")}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
