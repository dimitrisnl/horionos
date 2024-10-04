defmodule HorionosWeb.AuthLive.UserConfirmationLive do
  use HorionosWeb, :live_view

  alias Horionos.Accounts
  alias Horionos.Services.RateLimiter

  require Logger

  @impl Phoenix.LiveView
  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <.guest_view
      title="Confirm your email address"
      subtitle="Thank you for taking the time to go through your emails"
    >
      <div class="mx-auto max-w-xs">
        <.simple_form for={@form} id="confirmation_form" phx-submit="confirm_account">
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <:actions>
            <.button phx-disable-with="Confirming..." class="w-full">Confirm</.button>
          </:actions>
        </.simple_form>
      </div>
    </.guest_view>
    """
  end

  @impl Phoenix.LiveView
  def mount(%{"token" => token}, _session, socket) do
    form = to_form(%{"token" => token}, as: "user")

    socket
    |> assign(form: form)
    |> ok(layout: {HorionosWeb.Layouts, :guest}, temporary_assigns: [form: nil])
  end

  @impl Phoenix.LiveView
  def handle_event("confirm_account", %{"user" => %{"token" => token}}, socket) do
    case RateLimiter.check_rate("confirm_account:#{token}", 5, 300_000) do
      :ok ->
        confirm_account(token, socket)

      :error ->
        socket
        |> put_flash(:error, "Too many attempts. Please try again later.")
        |> redirect(to: ~p"/")
        |> noreply()
    end
  end

  defp confirm_account(token, socket) do
    case Accounts.confirm_user_email(token) do
      {:ok, user} ->
        Logger.info("User confirmed: #{user.email}")

        socket
        |> put_flash(:info, "Your account has been confirmed successfully.")
        |> redirect(to: ~p"/users/log_in")
        |> noreply()

      :error ->
        handle_invalid_token(socket)
    end
  end

  defp handle_invalid_token(socket) do
    case socket.assigns do
      %{current_user: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
        socket
        |> redirect(to: ~p"/")
        |> noreply()

      %{} ->
        # Log failed confirmation attempt
        Logger.warning("Invalid confirmation attempt with token")

        socket
        |> put_flash(
          :error,
          "The confirmation link is invalid or has expired. Please request a new one."
        )
        |> redirect(to: ~p"/")
        |> noreply()
    end
  end
end
