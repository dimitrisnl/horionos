defmodule HorionosWeb.UserSessionController do
  use HorionosWeb, :controller
  require Logger

  alias Horionos.Accounts
  alias Horionos.Services.RateLimiter
  alias HorionosWeb.UserAuth

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:user_return_to, ~p"/users/settings/security")
    |> do_create(params, "Password updated successfully!")
  end

  def create(conn, %{"_action" => "registered"} = params) do
    do_create(conn, params)
  end

  def create(conn, params) do
    do_create(conn, params)
  end

  defp do_create(conn, %{"user" => user_params}, info \\ "") do
    %{"email" => email, "password" => password} = user_params

    with :ok <- RateLimiter.check_rate("login:#{email}", 5, 300_000),
         user when not is_nil(user) <- Accounts.get_user_by_email_and_password(email, password) do
      Logger.info("Successful login for user: #{user.id}")
      conn = maybe_put_flash(conn, info)
      UserAuth.log_in_user(conn, user, user_params)
    else
      :error ->
        Logger.warning("Rate limit exceeded for login attempts: #{email}")

        conn
        |> put_flash(:error, "Too many login attempts. Please try again later.")
        |> redirect(to: ~p"/users/log_in")

      nil ->
        Logger.warning("Failed login attempt for email: #{email}")
        handle_failed_login(conn, email)
    end
  end

  defp maybe_put_flash(conn, info) when is_binary(info) and info != "",
    do: put_flash(conn, :info, info)

  defp maybe_put_flash(conn, _), do: conn

  defp handle_failed_login(conn, email) do
    conn
    |> put_flash(:error, "Invalid email or password")
    |> put_flash(:email, String.slice(email, 0, 160))
    |> redirect(to: ~p"/users/log_in")
  end

  def delete(conn, _params) do
    UserAuth.log_out_user(conn) |> redirect(to: ~p"/users/log_in")
  end
end
