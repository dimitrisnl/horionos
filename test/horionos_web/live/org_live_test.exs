defmodule HorionosWeb.OrgLiveTest do
  use HorionosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Horionos.AccountsFixtures
  import Horionos.OrgsFixtures

  alias Horionos.Orgs

  @update_attrs %{title: "Updated Org Name"}
  @invalid_attrs %{title: nil}

  describe "Index" do
    setup do
      owner = user_fixture()
      org = org_fixture(%{user: owner})
      admin = user_fixture()
      member = user_fixture()

      Orgs.create_membership(%{user_id: admin.id, org_id: org.id, role: :admin})
      Orgs.create_membership(%{user_id: member.id, org_id: org.id, role: :member})

      %{org: org, owner: owner, admin: admin, member: member}
    end

    test "displays current org details for admin and owners", %{
      conn: conn,
      org: org,
      admin: admin,
      owner: owner
    } do
      for user <- [admin, owner] do
        conn = log_in_user(conn, user)
        {:ok, _index_live, html} = live(conn, ~p"/org")

        assert html =~ "Settings"
        assert html =~ "Edit Organization"
        assert html =~ org.title
      end
    end

    test "cannot visit the page as member", %{conn: conn, member: member} do
      conn = log_in_user(conn, member)

      {:error,
       {:live_redirect,
        %{to: "/", flash: %{"error" => "You are not authorized to access this page."}}}} =
        live(conn, ~p"/org")
    end

    test "updates org", %{conn: conn, admin: admin, owner: owner} do
      for user <- [admin, owner] do
        conn = log_in_user(conn, user)
        {:ok, index_live, _html} = live(conn, ~p"/org")

        assert index_live
               |> form("#org-form", org: @update_attrs)
               |> render_submit()

        html = render(index_live)
        assert html =~ "Organization updated successfully"
        assert html =~ "Updated Org Name"
      end
    end

    test "displays error message with invalid attributes", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      {:ok, index_live, _html} = live(conn, ~p"/org")

      result =
        index_live
        |> form("#org-form", org: @invalid_attrs)
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end

    test "deletes org as owner", %{conn: conn, org: org, owner: owner} do
      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/org")

      delete_form = form(view, "#delete_org_form")

      assert has_element?(
               view,
               "form[data-confirm='Are you sure you want to delete the organization? This action cannot be undone.']"
             )

      render_submit(delete_form)

      assert_redirect(view, ~p"/")
      assert {:error, :not_found} = Orgs.get_org(org.id)
    end

    test "cannot delete org as admin", %{conn: conn, org: org, admin: admin} do
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/org")

      delete_form = form(view, "#delete_org_form")
      render_submit(delete_form)

      assert render(view) =~ "You are not authorized to delete this organization."
      assert {:ok, _org} = Orgs.get_org(org.id)
    end

    test "lists org members for admin and owner", %{
      conn: conn,
      owner: owner,
      admin: admin,
      member: member
    } do
      for user <- [admin, owner] do
        conn = log_in_user(conn, user)
        {:ok, _index_live, html} = live(conn, ~p"/org")

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
