defmodule HorionosWeb.AuthLive.UserConfirmationInstructionsLive do
  use HorionosWeb, :live_view

  require Logger

  alias Horionos.Accounts
  alias Horionos.Services.RateLimiter

  def render(assigns) do
    ~H"""
    <.guest_view
      title="No confirmation instructions received?"
      subtitle="We'll send a new confirmation link to your inbox"
    >
      <div class="mx-auto max-w-sm">
        <.simple_form for={@form} id="resend_confirmation_form" phx-submit="send_instructions">
          <.input field={@form[:email]} type="email" placeholder="Email" required />
          <:actions>
            <.button phx-disable-with="Sending..." class="w-full">
              Resend confirmation instructions
            </.button>
          </:actions>
        </.simple_form>
      </div>
    </.guest_view>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user")), layout: {HorionosWeb.Layouts, :guest}}
  end

  def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
    case RateLimiter.check_rate("confirmation_instructions:#{email}", 3, 300_000) do
      :ok ->
        if user = Accounts.get_user_by_email(email) do
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

          Logger.info("Confirmation instructions sent to #{email}")
        else
          Logger.warning(
            "Attempt to send confirmation instructions to non-existent email: #{email}"
          )
        end

        info =
          "If your email is in our system and it has not been confirmed yet, you will receive an email with instructions shortly."

        {:noreply,
         socket
         |> put_flash(:info, info)
         |> redirect(to: ~p"/")}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Too many requests. Please try again later.")
         |> assign(form: to_form(%{"email" => email}, as: "user"))}
    end
  end
end
