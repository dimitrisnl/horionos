defmodule HorionosWeb.OrgLiveTest do
  use HorionosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Horionos.AccountsFixtures
  import Horionos.OrgsFixtures

  alias Horionos.Orgs

  @update_attrs %{title: "Updated Org Name"}
  @invalid_attrs %{title: nil}

  describe "Index" do
    setup [:register_and_log_in_user]

    setup %{user: user} do
      org = org_fixture(%{user: user})
      %{org: org, user: user}
    end

    test "displays current org details", %{conn: conn, org: org} do
      {:ok, _index_live, html} = live(conn, ~p"/org")

      assert html =~ "Settings"
      assert html =~ "Edit Organization"
      assert html =~ org.title
    end

    test "updates org", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/org")

      assert index_live
             |> form("#org-form", org: @update_attrs)
             |> render_submit()

      html = render(index_live)
      assert html =~ "Organization updated successfully"
      assert html =~ "Updated Org Name"
    end

    test "displays error message with invalid attributes", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/org")

      result =
        index_live
        |> form("#org-form", org: @invalid_attrs)
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end

    test "deletes org", %{conn: conn, org: org, user: user} do
      {:ok, view, _html} = live(conn, ~p"/org")

      # Find the delete form
      delete_form = form(view, "#delete_org_form")

      # Ensure the form has the correct confirmation message
      assert has_element?(
               view,
               "form[data-confirm='Are you sure you want to delete the organization? This action cannot be undone.']"
             )

      # Simulate submitting the form
      render_submit(delete_form)

      # Check for redirect after submission
      assert_redirect(view, ~p"/")

      # Verify that the org has been deleted
      assert {:error, :unauthorized} = Orgs.get_org(user, org.id)
    end

    test "lists org members", %{conn: conn, org: org, user: user} do
      member = user_fixture()
      Orgs.create_membership(user, %{user_id: member.id, org_id: org.id, role: :member})

      {:ok, _index_live, html} = live(conn, ~p"/org")

      assert html =~ user.full_name
      assert html =~ user.email
      assert html =~ "owner"

      assert html =~ member.full_name
      assert html =~ member.email
      assert html =~ "member"
    end
  end
end
