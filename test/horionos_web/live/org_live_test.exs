defmodule HorionosWeb.OrgLiveTest do
  use HorionosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Horionos.OrgsFixtures

  @create_attrs %{title: "some name"}
  @update_attrs %{title: "some updated name"}
  @invalid_attrs %{title: nil}

  describe "Index" do
    setup [:register_and_log_in_user]

    setup %{user: user} do
      org = org_fixture(%{user: user})
      %{org: org}
    end

    test "lists all orgs", %{conn: conn, org: org} do
      {:ok, _index_live, html} = live(conn, ~p"/orgs")

      assert html =~ "Organizations"
      assert html =~ org.title
    end

    test "saves new org", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/orgs")

      assert index_live |> element("a", "New Organization") |> render_click() =~
               "New Organization"

      assert_patch(index_live, ~p"/orgs/new")

      assert index_live
             |> form("#org-form", org: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/orgs")

      html = render(index_live)
      assert html =~ "Organization created successfully"
      assert html =~ "some name"
    end

    test "updates org in listing", %{conn: conn, org: org} do
      {:ok, index_live, _html} = live(conn, ~p"/orgs")

      assert index_live |> element("#orgs-#{org.id} a", "Edit") |> render_click() =~
               "Edit Org"

      assert_patch(index_live, ~p"/orgs/#{org}/edit")

      assert index_live
             |> form("#org-form", org: @update_attrs)
             |> render_submit()

      html = render(index_live)
      assert html =~ "Organization updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes org in listing", %{conn: conn, org: org} do
      {:ok, index_live, _html} = live(conn, ~p"/orgs")

      assert index_live |> element("#orgs-#{org.id} a", "Delete") |> render_click()

      Process.sleep(100)

      if Process.alive?(index_live.pid) do
        refute has_element?(index_live, "#orgs-#{org.id}")
      else
        assert_redirect(index_live, "/orgs")
      end
    end

    test "shows error message with invalid attributes", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/orgs")

      assert index_live |> element("a", "New Organization") |> render_click() =~
               "New Organization"

      assert_patch(index_live, ~p"/orgs/new")

      result =
        index_live
        |> form("#org-form", org: @invalid_attrs)
        |> render_submit()

      assert result =~ "can&#39;t be blank"

      html = render(index_live)
      refute html =~ "Organization created successfully"
      assert html =~ "New organization"
    end
  end

  describe "Show" do
    setup [:register_and_log_in_user]

    setup %{user: user} do
      org = org_fixture(%{user: user})
      %{org: org}
    end

    test "displays org", %{conn: conn, org: org} do
      {:ok, _show_live, html} = live(conn, ~p"/orgs/#{org}")

      assert html =~ org.title
    end

    test "updates org within modal", %{conn: conn, org: org} do
      {:ok, show_live, _html} = live(conn, ~p"/orgs/#{org}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit"

      assert_patch(show_live, ~p"/orgs/#{org}/show/edit")

      assert show_live
             |> form("#org-form", org: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/orgs/#{org}")

      html = render(show_live)
      assert html =~ "some updated name"
    end
  end
end
