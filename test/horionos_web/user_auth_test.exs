defmodule HorionosWeb.UserAuthTest do
  use HorionosWeb.ConnCase, async: true

  alias Horionos.Accounts
  alias Horionos.Orgs
  alias HorionosWeb.UserAuth

  import Horionos.AccountsFixtures
  import Horionos.OrgsFixtures

  @remember_me_cookie "_horionos_web_user_remember_me"

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, HorionosWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{user: user_fixture(), conn: conn}
  end

  describe "log_in_user/3" do
    test "stores the user token in the session", %{conn: conn, user: user} do
      # Log in the user and check if the token is properly stored
      conn =
        conn
        |> fetch_flash()
        |> UserAuth.log_in_user(user)

      assert token = get_session(conn, :user_token)
      assert get_session(conn, :live_socket_id) == "users_sessions:#{Base.url_encode64(token)}"
      assert Accounts.get_user_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, user: user} do
      # Ensure previous session data is cleared on login
      conn =
        conn
        |> fetch_flash()
        |> put_session(:to_be_removed, "value")
        |> UserAuth.log_in_user(user)

      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, user: user} do
      # Check if user is redirected to the correct path after login
      conn =
        conn
        |> fetch_flash()
        |> put_session(:user_return_to, "/hello")
        |> UserAuth.log_in_user(user)

      assert redirected_to(conn) == "/onboarding"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, user: user} do
      # Verify remember_me functionality
      conn =
        conn
        |> fetch_flash()
        |> fetch_cookies()
        |> UserAuth.log_in_user(user, %{"remember_me" => "true"})

      assert get_session(conn, :user_token) == conn.cookies[@remember_me_cookie]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :user_token)
      assert max_age == 5_184_000
    end

    test "redirects to onboarding if user has no organization", %{conn: conn, user: user} do
      # Check redirection to onboarding for users without an org
      conn = conn |> fetch_flash() |> UserAuth.log_in_user(user)
      assert redirected_to(conn) == ~p"/onboarding"
    end

    test "redirects to primary org if user has an organization", %{conn: conn, user: user} do
      # Verify redirection to home page for users with an org
      Horionos.OrgsFixtures.org_fixture(%{user: user})

      conn = conn |> fetch_flash() |> UserAuth.log_in_user(user)

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :current_org_id)
    end

    test "handles race condition on session token creation", %{conn: conn, user: user} do
      # Simulate and test handling of race condition in token creation
      conn =
        conn
        |> fetch_flash()
        |> UserAuth.log_in_user(user)

      token = get_session(conn, :user_token)
      Accounts.delete_user_session_token(token)

      assert get_session(conn, :user_token)
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "logout_user/1" do
    test "erases session and cookies", %{conn: conn, user: user} do
      # Ensure logout properly clears session and cookies
      user_token = Accounts.generate_user_session_token(user)

      conn =
        conn
        |> put_session(:user_token, user_token)
        |> put_req_cookie(@remember_me_cookie, user_token)
        |> fetch_cookies()
        |> UserAuth.log_out_user()

      refute get_session(conn, :user_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
      refute Accounts.get_user_by_session_token(user_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      # Verify logout broadcasts disconnect event
      live_socket_id = "users_sessions:abcdef-token"
      HorionosWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> UserAuth.log_out_user()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if user is already logged out", %{conn: conn} do
      # Ensure logout function is idempotent
      conn = conn |> fetch_cookies() |> UserAuth.log_out_user()
      refute get_session(conn, :user_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_current_user/2" do
    test "authenticates user from session", %{conn: conn, user: user} do
      # Verify user authentication from session token
      user_token = Accounts.generate_user_session_token(user)
      conn = conn |> put_session(:user_token, user_token) |> UserAuth.fetch_current_user([])
      assert conn.assigns.current_user.id == user.id
    end

    test "authenticates user from cookies", %{conn: conn, user: user} do
      # Test user authentication from remember_me cookie
      logged_in_conn =
        conn
        |> fetch_flash()
        |> fetch_cookies()
        |> UserAuth.log_in_user(user, %{"remember_me" => "true"})

      user_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> UserAuth.fetch_current_user([])

      assert conn.assigns.current_user.id == user.id
      assert get_session(conn, :user_token) == user_token

      assert get_session(conn, :live_socket_id) ==
               "users_sessions:#{Base.url_encode64(user_token)}"
    end

    test "does not authenticate if data is missing", %{conn: conn, user: user} do
      # Ensure no authentication occurs with missing data
      _ = Accounts.generate_user_session_token(user)
      conn = UserAuth.fetch_current_user(conn, [])
      refute get_session(conn, :user_token)
      refute conn.assigns.current_user
    end
  end

  describe "fetch_current_org/2" do
    setup %{user: user} do
      org = org_fixture(%{user: user})
      %{org: org}
    end

    test "assigns current_org from session", %{conn: conn, user: user, org: org} do
      # Verify current_org is correctly assigned from session
      conn =
        conn
        |> Map.put(:params, %{})
        |> assign(:current_user, user)
        |> put_session(:current_org_id, org.id)
        |> UserAuth.fetch_current_org([])

      assert conn.assigns.current_org.id == org.id
      assert get_session(conn, :current_org_id) == org.id
    end

    test "assigns primary org if no org_id in session", %{conn: conn, user: user, org: org} do
      # Check if primary org is assigned when no org_id in session
      conn =
        conn
        |> Map.put(:params, %{})
        |> assign(:current_user, user)
        |> UserAuth.fetch_current_org([])

      assert conn.assigns.current_org.id == org.id
      assert get_session(conn, :current_org_id) == org.id
    end

    test "assigns nil if user has no orgs", %{conn: conn, user: user} do
      # Ensure nil is assigned when user has no organizations
      Orgs.delete_org(user, Orgs.get_user_primary_org(user))

      conn =
        conn
        |> Map.put(:params, %{})
        |> assign(:current_user, user)
        |> UserAuth.fetch_current_org([])

      assert conn.assigns.current_org == nil
      refute get_session(conn, :current_org_id)
    end

    test "does nothing if no current_user", %{conn: conn} do
      # Verify no action taken when there's no current user
      conn =
        conn
        |> Map.put(:params, %{})
        |> assign(:current_user, nil)
        |> UserAuth.fetch_current_org([])

      refute conn.assigns[:current_org]
      refute get_session(conn, :current_org_id)
    end

    test "handles switching between organizations", %{conn: conn, user: user} do
      # Test proper handling of org switching
      org1 = org_fixture(%{user: user})
      org2 = org_fixture(%{user: user})

      conn =
        conn
        |> assign(:current_user, user)
        |> put_session(:current_org_id, org1.id)
        |> UserAuth.fetch_current_org([])

      assert conn.assigns.current_org.id == org1.id

      conn =
        conn
        |> put_session(:current_org_id, org2.id)
        |> UserAuth.fetch_current_org([])

      assert conn.assigns.current_org.id == org2.id
    end

    test "handles case when org is deleted while user is logged in", %{conn: conn, user: user} do
      # Verify correct behavior when current org is deleted
      org1 = org_fixture(%{user: user})
      org2 = org_fixture(%{user: user})

      conn =
        conn
        |> assign(:current_user, user)
        |> put_session(:current_org_id, org1.id)
        |> UserAuth.fetch_current_org([])

      assert conn.assigns.current_org.id == org1.id

      {:ok, _deleted_org} = Orgs.delete_org(user, org1)
      assert {:error, :unauthorized} = Orgs.get_org(user, org1.id)

      updated_conn = UserAuth.fetch_current_org(conn, [])

      assert updated_conn.assigns.current_org.id != org1.id
      assert is_integer(updated_conn.assigns.current_org.id)
      assert get_session(updated_conn, :current_org_id) == updated_conn.assigns.current_org.id

      {:ok, _} = Orgs.delete_org(user, org2)
      {:ok, _} = Orgs.delete_org(user, updated_conn.assigns.current_org)

      final_conn = UserAuth.fetch_current_org(updated_conn, [])

      assert final_conn.assigns.current_org == nil
      refute get_session(final_conn, :current_org_id)
    end
  end

  describe "redirect_if_user_is_authenticated/2" do
    test "redirects if user is authenticated", %{conn: conn, user: user} do
      # Check redirection for authenticated users
      conn = conn |> assign(:current_user, user) |> UserAuth.redirect_if_user_is_authenticated([])
      assert conn.halted
      assert redirected_to(conn) == ~p"/"
    end

    test "does not redirect if user is not authenticated", %{conn: conn} do
      # Verify no redirection for unauthenticated users
      conn = UserAuth.redirect_if_user_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_user/2" do
    test "redirects if user is not authenticated", %{conn: conn} do
      # Ensure unauthenticated users are redirected to login
      conn = conn |> fetch_flash() |> UserAuth.require_authenticated_user([])
      assert conn.halted
      assert redirected_to(conn) == ~p"/users/log_in"
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      # Verify return path is stored for GET requests
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :user_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :user_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert halted_conn.halted
      refute get_session(halted_conn, :user_return_to)
    end

    test "does not redirect if user is authenticated", %{conn: conn, user: user} do
      # Check that authenticated users are not redirected
      conn = conn |> assign(:current_user, user) |> UserAuth.require_authenticated_user([])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_org/2" do
    setup %{user: user} do
      org = org_fixture(%{user: user})
      %{org: org}
    end

    test "does not redirect if user has an org", %{conn: conn, user: user, org: org} do
      # Verify no redirection when user has an org
      conn =
        conn
        |> assign(:current_user, user)
        |> assign(:current_org, org)
        |> UserAuth.require_org([])

      refute conn.halted
      refute conn.status
    end

    test "redirects to onboarding if user has no org", %{conn: conn, user: user} do
      # Ensure redirection to onboarding when user has no org
      conn =
        conn
        |> assign(:current_user, user)
        |> assign(:current_org, nil)
        |> UserAuth.require_org([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/onboarding"
    end
  end
end
