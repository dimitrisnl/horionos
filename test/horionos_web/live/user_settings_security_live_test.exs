defmodule HorionosWeb.UserSettingsLive.SecurityTest do
  use HorionosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Horionos.AccountsFixtures

  alias Horionos.Accounts

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      %{conn: conn} =
        HorionosWeb.ConnCase.register_and_log_in_user(%{conn: conn, create_org: true})

      {:ok, _lv, html} = live(conn, ~p"/users/settings/security")

      assert html =~ "Account Security"
      assert html =~ "Change your password"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      result = conn |> live(~p"/users/settings/security")
      assert {:error, {:redirect, %{to: "/users/log_in"}}} = result
    end
  end

  describe "update password form" do
    test "updates the user password", %{conn: conn} do
      email = unique_user_email()
      current_password = "old_password!"

      %{conn: conn} =
        HorionosWeb.ConnCase.register_and_log_in_user(%{
          conn: conn,
          create_org: true,
          user_attrs: %{password: current_password, email: email}
        })

      new_password = valid_user_password()

      {:ok, lv, _html} = live(conn, ~p"/users/settings/security")

      form =
        form(lv, "#password_form", %{
          "current_password" => current_password,
          "user" => %{
            "email" => email,
            "password" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/users/settings/security"

      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_user_by_email_and_password(email, new_password)
    end

    test "renders errors with invalid data", %{conn: conn} do
      %{conn: conn} =
        HorionosWeb.ConnCase.register_and_log_in_user(%{conn: conn, create_org: true})

      {:ok, lv, _html} = live(conn, ~p"/users/settings/security")

      result =
        lv
        |> element("#password_form")
        |> render_submit(%{
          "current_password" => "invalid",
          "user" => %{
            "password" => "too short"
          }
        })

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      %{conn: conn} =
        HorionosWeb.ConnCase.register_and_log_in_user(%{conn: conn, create_org: true})

      {:ok, lv, _html} = live(conn, ~p"/users/settings/security")

      result =
        lv
        |> form("#password_form", %{
          "current_password" => "invalid",
          "user" => %{
            "password" => "too short"
          }
        })
        |> render_submit()

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "is not valid"
    end
  end

  describe "active sessions" do
    setup %{conn: conn} do
      %{conn: conn, user: user} =
        HorionosWeb.ConnCase.register_and_log_in_user(%{conn: conn, create_org: true})

      # Create an additional session
      Accounts.generate_user_session_token(user, %{
        device: "Test Device",
        os: "Test OS",
        browser: "Test Browser",
        browser_version: "1.0"
      })

      %{conn: conn, user: user}
    end

    test "renders active sessions", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/settings/security")

      assert html =~ "Active sessions"
      assert html =~ "Test Device"
      assert html =~ "Test OS"
      assert html =~ "Test Browser"
      assert html =~ "version: 1.0"
      assert html =~ "Log out of all other sessions"
    end

    test "deletes other sessions", %{user: user, conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/users/settings/security")

      assert html =~ "Log out of all other sessions"

      form = form(lv, "#clear_sessions_form")
      render_submit(form)

      new_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_conn) == ~p"/users/settings/security"

      assert Phoenix.Flash.get(new_conn.assigns.flash, :info) =~
               "All other sessions have been logged out."

      # Verify that other sessions are deleted
      sessions = Accounts.get_user_sessions(user, get_session(new_conn, :user_token))
      assert length(sessions) == 1
      assert Enum.any?(sessions, fn session -> session.is_current end)
    end
  end
end
