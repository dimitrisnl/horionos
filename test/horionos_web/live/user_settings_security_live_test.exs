defmodule HorionosWeb.UserSettingsSecurityLiveTest do
  use HorionosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Horionos.AccountsFixtures

  alias Horionos.Accounts.Sessions
  alias Horionos.Accounts.Users

  describe "Settings page" do
    setup :setup_user_pipeline

    @tag create_organization: true
    @tag confirm_user_email: true
    @tag log_in_user: true
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/settings/security")

      assert html =~ "Security"
      assert html =~ "Change your password"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      result = conn |> live(~p"/users/settings/security")
      assert {:error, {:redirect, %{to: "/users/log_in"}}} = result
    end
  end

  describe "update password form" do
    setup :setup_user_pipeline

    @tag user_attrs: %{password: "old_password!", email: "some@email.com"}
    @tag create_organization: true
    @tag confirm_user_email: true
    @tag log_in_user: true
    test "updates the user password", %{conn: conn} do
      new_password = valid_user_password()
      {:ok, lv, _html} = live(conn, ~p"/users/settings/security")

      form =
        form(lv, "#password_form", %{
          "current_password" => "old_password!",
          "user" => %{
            "email" => "some@email.com",
            "password" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/users/settings/security"

      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert {:ok, _} = Users.get_user_by_email_and_password("some@email.com", new_password)
    end

    @tag create_organization: true
    @tag confirm_user_email: true
    @tag log_in_user: true
    test "renders errors with invalid data", %{conn: conn} do
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

    @tag create_organization: true
    @tag confirm_user_email: true
    @tag log_in_user: true
    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
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
    setup :setup_user_pipeline

    setup %{conn: conn, user: user} do
      # Create an additional session
      Sessions.create_session(user, %{
        device: "Test Device",
        os: "Test OS",
        browser: "Test Browser",
        browser_version: "1.0"
      })

      %{conn: conn, user: user}
    end

    @tag create_organization: true
    @tag confirm_user_email: true
    @tag log_in_user: true
    test "renders active sessions", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/settings/security")

      assert html =~ "Active sessions"
      assert html =~ "Test Device"
      assert html =~ "Test OS"
      assert html =~ "Test Browser"
      assert html =~ "version: 1.0"
      assert html =~ "Log out of all other sessions"
    end

    @tag create_organization: true
    @tag confirm_user_email: true
    @tag log_in_user: true
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
      sessions = Sessions.list_sessions(user, get_session(new_conn, :user_token))
      assert length(sessions) == 1
      assert Enum.any?(sessions, fn session -> session.is_current end)
    end
  end
end
