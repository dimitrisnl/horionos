defmodule HorionosWeb.AuthLive.UserResetPasswordLive do
  use HorionosWeb, :live_view
  require Logger

  alias Horionos.Accounts
  alias Horionos.Services.RateLimiter

  def render(assigns) do
    ~H"""
    <.guest_view title="Reset password">
      <.card>
        <.simple_form for={@form} id="reset_password_form" phx-submit="reset_password">
          <.input field={@form[:password]} type="password" label="New password" required />
          <:actions>
            <.button phx-disable-with="Resetting..." class="w-full">Reset Password</.button>
          </:actions>
        </.simple_form>
      </.card>
    </.guest_view>
    """
  end

  def mount(params, _session, socket) do
    socket = assign_user_and_token(socket, params)

    form_source =
      case socket.assigns do
        %{user: user} ->
          Accounts.change_user_password(user)

        _ ->
          %{}
      end

    {:ok, assign_form(socket, form_source),
     temporary_assigns: [form: nil], layout: {HorionosWeb.Layouts, :guest}}
  end

  def handle_event("reset_password", %{"user" => user_params}, socket) do
    case RateLimiter.check_rate("reset_password:#{socket.assigns.user.id}", 5, 3_600_000) do
      :ok ->
        case Accounts.reset_user_password(socket.assigns.user, user_params) do
          {:ok, _} ->
            Logger.info("Password reset successful for user: #{socket.assigns.user.id}")

            {:noreply,
             socket
             |> put_flash(
               :info,
               "Password reset successfully. Please log in with your new password."
             )
             |> redirect(to: ~p"/users/log_in")}

          {:error, changeset} ->
            Logger.warning("Failed password reset attempt for user: #{socket.assigns.user.id}")
            {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
        end

      :error ->
        Logger.warning("Rate limit exceeded for password reset: #{socket.assigns.user.id}")

        {:noreply,
         socket
         |> put_flash(:error, "Too many password reset attempts. Please try again later.")
         |> redirect(to: ~p"/")}
    end
  end

  defp assign_user_and_token(socket, %{"token" => token}) do
    if user = Accounts.get_user_by_reset_password_token(token) do
      assign(socket, user: user, token: token)
    else
      Logger.warning("Invalid or expired reset password token used")

      socket
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: ~p"/")
    end
  end

  defp assign_form(socket, %{} = source) do
    assign(socket, :form, to_form(source, as: "user"))
  end
end
