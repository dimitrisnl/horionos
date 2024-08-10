defmodule HorionosWeb.UserAuthLiveLiveTest do
  use HorionosWeb.ConnCase, async: true

  alias Horionos.Accounts
  alias HorionosWeb.UserAuthLive
  alias Phoenix.LiveView

  import Horionos.AccountsFixtures
  import Horionos.OrgsFixtures

  setup %{conn: conn} do
    # Set up a test connection with a new session
    conn =
      conn
      |> Map.replace!(:secret_key_base, HorionosWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{user: user_fixture(), conn: conn}
  end

  describe "on_mount :mount_current_user" do
    test "assigns current_user based on a valid user_token", %{conn: conn, user: user} do
      # Test that a valid user token results in the correct current_user assignment
      user_token = Accounts.create_session_token(user)
      session = conn |> put_session(:user_token, user_token) |> get_session()

      {:cont, updated_socket} =
        UserAuthLive.on_mount(:mount_current_user, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_user.id == user.id
    end

    test "assigns nil to current_user assign if there isn't a valid user_token", %{conn: conn} do
      # Verify that an invalid token results in a nil current_user
      user_token = "invalid_token"
      session = conn |> put_session(:user_token, user_token) |> get_session()

      {:cont, updated_socket} =
        UserAuthLive.on_mount(:mount_current_user, %{}, session, %LiveView.Socket{})

      assert is_nil(updated_socket.assigns.current_user)
    end

    test "assigns nil to current_user assign if there isn't a user_token", %{conn: conn} do
      # Check that absence of a token results in a nil current_user
      session = conn |> get_session()

      {:cont, updated_socket} =
        UserAuthLive.on_mount(:mount_current_user, %{}, session, %LiveView.Socket{})

      assert is_nil(updated_socket.assigns.current_user)
    end
  end

  describe "on_mount :ensure_authenticated" do
    test "authenticates current_user based on a valid user_token", %{conn: conn, user: user} do
      # Test successful authentication with a valid token
      user_token = Accounts.create_session_token(user)
      session = conn |> put_session(:user_token, user_token) |> get_session()

      {:cont, updated_socket} =
        UserAuthLive.on_mount(:ensure_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_user.id == user.id
    end

    test "redirects to login page if there isn't a valid user_token", %{conn: conn} do
      # Verify redirection to login page with an invalid token
      user_token = "invalid_token"
      session = conn |> put_session(:user_token, user_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: HorionosWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = UserAuthLive.on_mount(:ensure_authenticated, %{}, session, socket)
      assert is_nil(updated_socket.assigns.current_user)
    end

    test "redirects to login page if there isn't a user_token", %{conn: conn} do
      # Check redirection to login page when no token is present
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: HorionosWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = UserAuthLive.on_mount(:ensure_authenticated, %{}, session, socket)
      assert is_nil(updated_socket.assigns.current_user)
    end
  end

  describe "on_mount :ensure_current_org" do
    test "assigns current_org based on a valid org_id", %{conn: conn, user: user} do
      # Test correct org assignment with a valid org_id
      org = org_fixture(%{user: user})
      user_token = Accounts.create_session_token(user)

      session =
        conn
        |> put_session(:user_token, user_token)
        |> put_session(:current_org_id, org.id)
        |> get_session()

      socket = %LiveView.Socket{
        endpoint: HorionosWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}, current_user: user}
      }

      {:cont, updated_socket} =
        UserAuthLive.on_mount(:ensure_current_org, %{}, session, socket)

      assert updated_socket.assigns.current_org.id == org.id
    end

    test "handles case when user has multiple orgs", %{conn: conn, user: user} do
      # Verify correct org assignment when user has multiple orgs
      org_fixture(%{user: user})
      org2 = org_fixture(%{user: user})
      user_token = Accounts.create_session_token(user)

      session =
        conn
        |> put_session(:user_token, user_token)
        |> put_session(:current_org_id, org2.id)
        |> get_session()

      socket = %LiveView.Socket{
        endpoint: HorionosWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}, current_user: user}
      }

      {:cont, updated_socket} =
        UserAuthLive.on_mount(:ensure_current_org, %{}, session, socket)

      assert updated_socket.assigns.current_org.id == org2.id
    end

    test "redirects to onboarding if there isn't a valid org_id", %{conn: conn, user: user} do
      # Check redirection to onboarding when no valid org_id is present
      user_token = Accounts.create_session_token(user)
      session = conn |> put_session(:user_token, user_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: HorionosWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}, current_user: user}
      }

      {:halt, updated_socket} = UserAuthLive.on_mount(:ensure_current_org, %{}, session, socket)
      assert updated_socket.assigns.current_org == nil
    end
  end

  describe "on_mount :redirect_if_user_is_authenticated" do
    test "redirects if there is an authenticated user", %{conn: conn, user: user} do
      # Verify redirection for authenticated users
      user_token = Accounts.create_session_token(user)
      session = conn |> put_session(:user_token, user_token) |> get_session()

      assert {:halt, _updated_socket} =
               UserAuthLive.on_mount(
                 :redirect_if_user_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end

    test "doesn't redirect if there is no authenticated user", %{conn: conn} do
      # Check that unauthenticated users are not redirected
      session = conn |> get_session()

      assert {:cont, _updated_socket} =
               UserAuthLive.on_mount(
                 :redirect_if_user_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end
  end

  describe "on_mount :redirect_if_locked" do
    test "redirects if the user is locked", %{conn: conn, user: user} do
      user_token = Accounts.create_session_token(user)
      {:ok, user} = Accounts.lock_user(user)

      session =
        conn
        |> put_session(:user_token, user_token)
        |> get_session()

      socket = %LiveView.Socket{
        endpoint: HorionosWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}, current_user: user}
      }

      assert {:halt, _updated_socket} =
               UserAuthLive.on_mount(
                 :redirect_if_locked,
                 %{},
                 session,
                 socket
               )
    end

    test "doesn't redirect an valid user", %{conn: conn, user: user} do
      user_token = Accounts.create_session_token(user)

      session =
        conn
        |> put_session(:user_token, user_token)
        |> get_session()

      socket = %LiveView.Socket{
        endpoint: HorionosWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}, current_user: user}
      }

      assert {:cont, _updated_socket} =
               UserAuthLive.on_mount(
                 :redirect_if_locked,
                 %{},
                 session,
                 socket
               )
    end
  end
end
