defmodule HorionosWeb.AuthLive.UserConfirmationInstructionsLive do
  use HorionosWeb, :live_view

  alias Horionos.Accounts
  alias Horionos.Services.RateLimiter

  require Logger

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.guest_view
      title={
        if @instructions_sent,
          do: "Confirmation instructions sent",
          else: "Resend confirmation instructions"
      }
      subtitle={
        if @instructions_sent,
          do:
            "You will receive an email with instructions shortly. Please check your email inbox and follow the instructions to confirm your account.",
          else: "We'll send a new confirmation link to your inbox"
      }
    >
      <div class="mx-auto max-w-sm">
        <%= if @instructions_sent do %>
          <div class="size-12 bg-emerald-100/75 mx-auto flex items-center justify-center rounded-full border border-emerald-200">
            <.icon name="hero-envelope" class="size-7 text-emerald-600" />
          </div>
        <% else %>
          <.simple_form for={@form} id="resend_confirmation_form" phx-submit="send_instructions">
            <.input field={@form[:email]} type="email" placeholder="Email" required />
            <:actions>
              <.button phx-disable-with="Sending..." class="w-full">
                Resend confirmation instructions
              </.button>
            </:actions>
          </.simple_form>
        <% end %>
      </div>
    </.guest_view>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket
    |> assign(instructions_sent: false)
    |> assign(form: to_form(%{}, as: "user"))
    |> ok(layout: {HorionosWeb.Layouts, :guest})
  end

  @impl Phoenix.LiveView
  def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
    case RateLimiter.check_rate("confirmation_instructions:#{email}", 3, 300_000) do
      :ok ->
        if user = Accounts.get_user_by_email(email) do
          Accounts.send_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

          Logger.info("Confirmation instructions sent to #{email}")
        else
          Logger.warning(
            "Attempt to send confirmation instructions to non-existent email: #{email}"
          )
        end

        socket
        |> assign(instructions_sent: true)
        |> assign(form: to_form(%{}, as: "user"))
        |> noreply()

      :error ->
        socket
        |> put_flash(:error, "Too many requests. Please try again later.")
        |> assign(form: to_form(%{"email" => email}, as: "user"))
        |> noreply()
    end
  end
end
