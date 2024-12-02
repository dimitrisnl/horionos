defmodule HorionosWeb.OrganizationSessionControllerTest do
  use HorionosWeb.ConnCase, async: true

  import Horionos.AccountsFixtures
  import Horionos.OrganizationsFixtures

  require Logger

  setup %{conn: conn} do
    setup_user_pipeline(%{
      conn: conn,
      create_organization: true,
      confirm_user_email: true,
      log_in_user: true
    })
  end

  describe "POST /organization/select" do
    test "switches to a new organization successfully", %{conn: conn, user: user} do
      new_organization = organization_fixture(%{user: user})

      conn = post(conn, "/organization/select", %{"organization_id" => new_organization.id})

      assert redirected_to(conn) == "/"
      assert get_session(conn, :current_organization_id) == new_organization.id

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Switched to #{new_organization.title}"
    end

    test "fails to switch to an invalid organization ID", %{conn: conn} do
      conn = post(conn, "/organization/select", %{"organization_id" => "invalid"})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid organization selected"
    end

    test "fails to switch to the same organization", %{conn: conn, organization: organization} do
      conn = post(conn, "/organization/select", %{"organization_id" => organization.id})

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "You are already viewing this organization"
    end

    test "fails to switch to an organization the user doesn't have access to", %{
      conn: conn
    } do
      # Create another user and organization they do not have access to
      other_user = user_fixture()
      other_organization = organization_fixture(%{user: other_user})

      conn = post(conn, "/organization/select", %{"organization_id" => other_organization.id})

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Organization not found"
    end

    test "fails to switch to an organization that doesn't exist", %{
      conn: conn
    } do
      conn = post(conn, "/organization/select", %{"organization_id" => 10_000_000})

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Organization not found"
    end
  end
end
