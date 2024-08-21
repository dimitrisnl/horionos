defmodule HorionosWeb.UserSettingsLive.IndexTest do
  use HorionosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Horionos.AccountsFixtures

  alias Horionos.Accounts

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      %{conn: conn} =
        HorionosWeb.ConnCase.register_and_log_in_user(%{conn: conn, create_org: true})

      {:ok, _lv, html} = live(conn, ~p"/users/settings")

      assert html =~ "Settings"
      assert html =~ "Change your display name"
      assert html =~ "Change your email address"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      result = conn |> live(~p"/users/settings")
      assert {:error, {:redirect, %{to: "/users/log_in"}}} = result
    end
  end

  describe "Update email form" do
    setup :register_and_log_in_user

    @tag create_org: true
    test "updates the user email", %{conn: conn, user: user} do
      new_email = unique_user_email()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => valid_user_password(),
          "user" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Accounts.get_user_by_email(user.email)
    end

    @tag create_org: true
    test "renders errors with invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#email_form")
        |> render_submit(%{
          "action" => "update_email",
          "current_password" => "invalid",
          "user" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email"
      assert result =~ "must have the @ sign and no spaces"
    end

    @tag create_org: true
    test "renders errors with invalid data (phx-submit)", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => "invalid",
          "user" => %{"email" => user.email}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "did not change"
      assert result =~ "is not valid"
    end
  end

  describe "Change display name" do
    setup :register_and_log_in_user

    @tag create_org: true
    test "updates the user display name", %{conn: conn, user: user} do
      new_full_name = "New Display Name"

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#full_name_form", %{
          "user" => %{"full_name" => new_full_name}
        })
        |> render_submit()

      assert result =~ "Name updated successfully"

      assert Accounts.get_user_by_email(user.email) == %Accounts.User{
               user
               | full_name: new_full_name
             }
    end

    @tag create_org: true
    test "renders errors with invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#full_name_form", %{
          "user" => %{"full_name" => ""}
        })
        |> render_submit()

      assert result =~ "be blank"
    end
  end

  describe "Confirm email" do
    setup :register_and_log_in_user

    setup %{conn: conn, user: user} do
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.send_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{conn: conn, token: token, email: email, user: user}
    end

    @tag create_org: true
    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm_email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert flash["info"] == "Email changed successfully."
      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/users/settings/confirm_email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert flash["error"] == "Email change link is invalid or it has expired."
    end

    @tag create_org: true
    test "does not update email with invalid token", %{conn: conn, user: user} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm_email/oops")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert flash["error"] == "Email change link is invalid or it has expired."

      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()

      {:error, {:redirect, %{to: "/users/log_in"}}} =
        live(conn, ~p"/users/settings/confirm_email/#{token}")
    end
  end
end
