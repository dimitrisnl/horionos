defmodule HorionosWeb.OrganizationLiveTest do
  use HorionosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Horionos.AccountsFixtures
  import Horionos.OrganizationsFixtures

  alias Horionos.Memberships.Memberships
  alias Horionos.Organizations.Organizations

  @update_attrs %{title: "Updated Organization Name"}
  @invalid_attrs %{title: nil}

  describe "Index" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})
      admin = user_fixture()
      member = user_fixture()

      Memberships.create_membership(%{
        user_id: admin.id,
        organization_id: organization.id,
        role: :admin
      })

      Memberships.create_membership(%{
        user_id: member.id,
        organization_id: organization.id,
        role: :member
      })

      %{organization: organization, owner: owner, admin: admin, member: member}
    end

    test "displays current organization details for member, admin, owners", %{
      conn: conn,
      organization: organization,
      admin: admin,
      owner: owner,
      member: member
    } do
      for user <- [admin, owner, member] do
        conn = log_in_user(conn, user)
        {:ok, _index_live, html} = live(conn, ~p"/organization")

        assert html =~ "Settings"
        assert html =~ "Edit Organization"
        assert html =~ organization.title
      end
    end

    test "updates organization", %{conn: conn, admin: admin, owner: owner} do
      for user <- [admin, owner] do
        conn = log_in_user(conn, user)
        {:ok, index_live, _html} = live(conn, ~p"/organization")

        assert index_live
               |> form("#organization-form", organization: @update_attrs)
               |> render_submit()

        html = render(index_live)
        assert html =~ "Organization updated successfully"
        assert html =~ "Updated Organization Name"
      end
    end

    test "displays error message with invalid attributes", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      {:ok, index_live, _html} = live(conn, ~p"/organization")

      result =
        index_live
        |> form("#organization-form", organization: @invalid_attrs)
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end

    test "deletes organization as owner", %{conn: conn, organization: organization, owner: owner} do
      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/organization")

      delete_form = form(view, "#delete_organization_form")

      assert has_element?(
               view,
               "form[data-confirm='Are you sure you want to delete the organization? This action cannot be undone.']"
             )

      render_submit(delete_form)

      assert_redirect(view, ~p"/")
      assert {:error, :not_found} = Organizations.get_organization(organization.id)
    end

    test "cannot delete organization as admin", %{
      conn: conn,
      organization: organization,
      admin: admin
    } do
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/organization")

      delete_form = form(view, "#delete_organization_form")
      render_submit(delete_form)

      assert render(view) =~ "You are not authorized to delete this organization."
      assert {:ok, _organization} = Organizations.get_organization(organization.id)
    end

    test "lists organization members for admin and owner", %{
      conn: conn,
      owner: owner,
      admin: admin,
      member: member
    } do
      for user <- [admin, owner] do
        conn = log_in_user(conn, user)
        {:ok, _index_live, html} = live(conn, ~p"/organization")

        assert html =~ owner.full_name
        assert html =~ owner.email
        assert html =~ "owner"

        assert html =~ admin.full_name
        assert html =~ admin.email
        assert html =~ "admin"

        assert html =~ member.full_name
        assert html =~ member.email
        assert html =~ "member"
      end
    end
  end
end
