defmodule HorionosWeb.Auth.UserForgotPasswordLive do
  use HorionosWeb, :live_view

  alias Horionos.Accounts.PasswordReset
  alias Horionos.Accounts.Users
  alias Horionos.Services.RateLimiter

  require Logger

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.guest_view
      title="Forgot your password?"
      subtitle="No worries, we'll send a password reset link to your inbox"
    >
      <div class="mx-auto max-w-sm">
        <.simple_form for={@form} id="reset_password_form" phx-submit="send_email">
          <.input field={@form[:email]} type="email" placeholder="Email" required />
          <:actions>
            <.button phx-disable-with="Sending..." class="w-full">
              Send password reset instructions
            </.button>
          </:actions>
        </.simple_form>
      </div>
    </.guest_view>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket
    |> assign(form: to_form(%{}, as: "user"))
    |> ok(layout: {HorionosWeb.Layouts, :guest})
  end

  @impl Phoenix.LiveView
  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    case RateLimiter.check_rate("reset_password:#{email}", 3, 3_600_000) do
      {:ok} ->
        process_reset_password_request(email, socket)

      {:error, :rate_limit_exceeded} ->
        handle_rate_limit_exceeded(socket)
    end
  end

  defp process_reset_password_request(email, socket) do
    if user = Users.get_user_by_email(email) do
      PasswordReset.initiate_reset(
        user,
        &url(~p"/users/reset_password/#{&1}")
      )

      Logger.info("Password reset instructions sent to: #{email}")
    else
      Logger.warning("Password reset attempted for non-existent email: #{email}")
    end

    info =
      "If your email is in our system, you will receive instructions to reset your password shortly."

    socket
    |> put_flash(:info, info)
    |> redirect(to: ~p"/")
    |> noreply()
  end

  defp handle_rate_limit_exceeded(socket) do
    Logger.warning("Rate limit exceeded for password reset")

    socket
    |> put_flash(:error, "Too many requests. Please try again later.")
    |> assign(form: to_form(%{}, as: "user"))
    |> noreply()
  end
end
