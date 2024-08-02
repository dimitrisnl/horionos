defmodule HorionosWeb.OrgSessionControllerTest do
  require Logger
  use HorionosWeb.ConnCase, async: true

  import Horionos.AccountsFixtures
  import Horionos.OrgsFixtures

  setup %{conn: conn} do
    %{conn: conn, user: user, org: org} =
      HorionosWeb.ConnCase.register_and_log_in_user(%{conn: conn, create_org: true})

    %{conn: conn, user: user, org: org}
  end

  describe "POST /org/select" do
    test "switches to a new organization successfully", %{conn: conn, user: user} do
      new_org = org_fixture(%{user: user})

      conn = post(conn, "/org/select", %{"org_id" => new_org.id})

      assert redirected_to(conn) == "/"
      assert get_session(conn, :current_org_id) == new_org.id
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Switched to #{new_org.title}"
    end

    test "fails to switch to an invalid organization ID", %{conn: conn} do
      conn = post(conn, "/org/select", %{"org_id" => "invalid"})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid organization selected"
    end

    test "fails to switch to the same organization", %{conn: conn, org: org} do
      conn = post(conn, "/org/select", %{"org_id" => org.id})

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "You are already viewing this organization"
    end

    test "fails to switch to an organization the user doesn't have access to", %{
      conn: conn
    } do
      # Create another user and organization they do not have access to
      other_user = user_fixture()
      other_org = org_fixture(%{user: other_user})

      conn = post(conn, "/org/select", %{"org_id" => other_org.id})

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You do not have access to this organization"
    end
  end
end
