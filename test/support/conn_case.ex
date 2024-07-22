defmodule HorionosWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use HorionosWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint HorionosWeb.Endpoint

      use HorionosWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import HorionosWeb.ConnCase
    end
  end

  setup tags do
    Horionos.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  import Plug.Conn

  @doc """
  Setup helper that registers and logs in users, and optionally creates an organization for them.

      setup :register_and_log_in_user

  It stores an updated connection, a registered user, and optionally the user's organization in the
  test context. Use the `create_org` tag to control whether an organization is created.
  """
  def register_and_log_in_user(context) do
    %{conn: conn} = context
    create_org = Map.get(context, :create_org, false)
    user_attrs = Map.get(context, :user_attrs, %{})

    user = Horionos.AccountsFixtures.user_fixture(user_attrs)

    conn = log_in_user(conn, user)

    result = %{conn: conn, user: user}

    if create_org do
      org = Horionos.OrgsFixtures.org_fixture(%{user: user})

      conn =
        conn
        |> put_session(:current_org_id, org.id)
        |> assign(:current_org, org)

      result
      |> Map.put(:org, org)
      |> Map.put(:conn, conn)
    else
      result
    end
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user) do
    token = Horionos.Accounts.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  def log_in_and_onboard_user(conn, user) do
    conn = log_in_user(conn, user)
    org = Horionos.OrgsFixtures.org_fixture(%{user: user})

    conn =
      conn
      |> put_session(:current_org_id, org.id)
      |> assign(:current_org, org)

    conn
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.assigns.url, "[TOKEN]")
    token
  end

  def assign_org(conn, org) do
    conn
    |> Plug.Conn.assign(:current_org, org)
    |> Plug.Conn.put_session(:current_org_id, org.id)
  end
end
