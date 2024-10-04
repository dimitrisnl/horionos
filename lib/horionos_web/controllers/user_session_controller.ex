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

  def create(conn, %{"_action" => "invitation_accepted"} = params) do
    do_create(conn, params, "Invitation accepted successfully!")
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

      device_info = extract_user_agent_info(conn)

      UserAuth.log_in_user(conn, user, user_params, device_info)
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

  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user()
    |> redirect(to: ~p"/users/log_in")
  end

  def delete_other_sessions(conn, _params) do
    user = conn.assigns.current_user
    user_token = get_session(conn, :user_token)

    case Accounts.revoke_other_user_sessions(user, user_token) do
      {deleted_count, nil} when deleted_count > 0 ->
        conn
        |> put_flash(:info, "All other sessions have been logged out.")
        |> redirect(to: ~p"/users/settings/security")

      _ ->
        conn
        |> put_flash(:error, "Failed to log out other sessions. Please try again.")
        |> redirect(to: ~p"/users/settings/security")
    end
  end

  ## Private functions

  defp maybe_put_flash(conn, info) when is_binary(info) and info != "",
    do: put_flash(conn, :info, info)

  defp maybe_put_flash(conn, _), do: conn

  defp handle_failed_login(conn, email) do
    conn
    |> put_flash(:error, "Invalid email or password")
    |> put_flash(:email, String.slice(email, 0, 160))
    |> redirect(to: ~p"/users/log_in")
  end

  defp extract_user_agent_info(conn) do
    ua =
      conn
      |> Plug.Conn.get_req_header("user-agent")
      |> List.first()
      |> UAParser.parse()

    browser_version =
      case ua.version do
        %{major: major, minor: minor, patch: patch} when not is_nil(patch) ->
          "#{major}.#{minor}.#{patch}"

        %{major: major, minor: minor} ->
          "#{major}.#{minor}"

        _ ->
          ""
      end

    os_version =
      case ua.os.version do
        %{major: major, minor: minor, patch: patch} when not is_nil(patch) ->
          "#{major}.#{minor}.#{patch}"

        %{major: major, minor: minor} ->
          "#{major}.#{minor}"

        _ ->
          ""
      end

    %{
      device: ua.device.family || "unknown",
      os: "#{ua.os.family} #{os_version}" |> String.trim(),
      browser: ua.family || "unknown",
      browser_version: browser_version
    }
  rescue
    _ ->
      %{
        device: "unknown",
        os: "unknown",
        browser: "unknown",
        browser_version: ""
      }
  end
end
