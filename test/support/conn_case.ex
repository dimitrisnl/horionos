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

  import Plug.Conn
  import Phoenix.ConnTest

  alias Horionos.Accounts.Sessions
  alias Horionos.AccountsFixtures
  alias Horionos.OrganizationsFixtures
  alias Horionos.Repo

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

  @doc """
  Setup-helper
  """
  def setup_user_pipeline(context) do
    context
    |> create_user()
    |> maybe_create_organization()
    |> maybe_confirm_email()
    |> maybe_log_in_user()
    |> maybe_assign_organization()
  end

  defp create_user(%{user_attrs: user_attrs} = context) do
    user = AccountsFixtures.user_fixture(user_attrs)
    Map.put(context, :user, user)
  end

  defp create_user(context) do
    user = AccountsFixtures.user_fixture(%{})
    Map.put(context, :user, user)
  end

  defp maybe_confirm_email(%{confirm_user_email: true, user: user} = context) do
    updated_user =
      Repo.update!(Ecto.Changeset.change(user, confirmed_at: NaiveDateTime.utc_now(:second)))

    Map.put(context, :user, updated_user)
  end

  defp maybe_confirm_email(context), do: context

  defp maybe_log_in_user(%{conn: conn, user: user, log_in_user: true} = context) do
    conn = log_in_user(conn, user)
    Map.put(context, :conn, conn)
  end

  defp maybe_log_in_user(context), do: context

  defp maybe_create_organization(%{create_organization: true, user: user} = context) do
    organization = OrganizationsFixtures.organization_fixture(%{user: user})
    Map.put(context, :organization, organization)
  end

  defp maybe_create_organization(context), do: context

  defp maybe_assign_organization(
         %{create_organization: true, conn: conn, organization: organization, log_in_user: true} =
           context
       ) do
    conn =
      conn
      |> put_session(:current_organization_id, organization.id)
      |> assign(:current_organization, organization)

    context
    |> Map.put(:conn, conn)
  end

  defp maybe_assign_organization(context), do: context

  @doc """
  Logs the given `user` into the `conn` by creating a session token.
  """
  def log_in_user(conn, user) do
    token = Sessions.create_session(user)

    conn
    |> init_test_session(%{})
    |> put_session(:user_token, token)
  end

  def extract_user_token(fun) do
    {:ok, captured_emails} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    captured_email = captured_emails[Horionos.Accounts.Notifications.Channels.Email]
    [_, token | _] = String.split(captured_email.assigns.url, "[TOKEN]")
    token
  end
end
