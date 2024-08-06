defmodule HorionosWeb.UserSessionControllerTest do
  require Logger
  use HorionosWeb.ConnCase, async: true

  import Horionos.AccountsFixtures

  describe "POST /users/log_in" do
    test "logs the user in", %{conn: conn} do
      %{conn: conn, user: user} =
        HorionosWeb.ConnCase.register_and_log_in_user(%{conn: conn, create_org: true})

      conn = delete(conn, ~p"/users/log_out")

      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ user.email
      assert response =~ ~p"/users/settings"
      assert response =~ ~p"/users/log_out"
    end

    test "logs the user in with remember me", %{conn: conn} do
      %{conn: conn, user: user} =
        HorionosWeb.ConnCase.register_and_log_in_user(%{conn: conn, create_org: true})

      conn = delete(conn, ~p"/users/log_out")

      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_horionos_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the user in with return to", %{conn: conn} do
      %{conn: conn, user: user} =
        HorionosWeb.ConnCase.register_and_log_in_user(%{conn: conn, create_org: true})

      delete(conn, ~p"/users/log_out")

      conn =
        Phoenix.ConnTest.build_conn()
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(~p"/users/log_in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
    end

    test "login following registration", %{conn: conn} do
      %{conn: conn, user: user} =
        HorionosWeb.ConnCase.register_and_log_in_user(%{conn: conn, create_org: true})

      conn = delete(conn, ~p"/users/log_out")

      conn =
        conn
        |> post(~p"/users/log_in", %{
          "_action" => "registered",
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == ~p"/"
    end

    test "login following password update", %{conn: conn} do
      %{conn: conn, user: user} =
        HorionosWeb.ConnCase.register_and_log_in_user(%{conn: conn, create_org: true})

      conn = delete(conn, ~p"/users/log_out")

      conn =
        conn
        |> post(~p"/users/log_in", %{
          "_action" => "password_updated",
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == ~p"/users/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Password updated successfully"
    end

    test "redirects to login page with invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => "invalid@email.com", "password" => "invalid_password"}
        })

      assert redirected_to(conn) == ~p"/users/log_in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
    end
  end

  describe "DELETE /users/log_out" do
    test "logs the user out", %{conn: conn} do
      %{conn: conn} =
        HorionosWeb.ConnCase.register_and_log_in_user(%{conn: conn, create_org: true})

      conn = conn |> delete(~p"/users/log_out")
      assert redirected_to(conn) == ~p"/users/log_in"
      refute get_session(conn, :user_token)
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log_out")
      assert redirected_to(conn) == ~p"/users/log_in"
      refute get_session(conn, :user_token)
    end
  end
end
