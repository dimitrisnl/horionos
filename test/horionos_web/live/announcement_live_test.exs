defmodule HorionosWeb.AnnouncementLiveTest do
  use HorionosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Horionos.AnnouncementsFixtures

  @create_attrs %{title: "some title", body: "some body"}
  @update_attrs %{title: "some updated title", body: "some updated body"}
  @invalid_attrs %{title: nil, body: nil}

  describe "Index" do
    setup [:register_and_log_in_user]

    setup %{user: user, org: org} do
      announcement = announcement_fixture(user, org)
      %{announcement: announcement}
    end

    @tag create_org: true
    test "lists all announcements", %{conn: conn, announcement: announcement} do
      {:ok, _index_live, html} = live(conn, ~p"/announcements")

      assert html =~ "Listing Announcements"
      assert html =~ announcement.title
    end

    @tag create_org: true
    test "saves new announcement", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/announcements")

      assert index_live |> element("a", "New Announcement") |> render_click() =~
               "New Announcement"

      assert_patch(index_live, ~p"/announcements/new")

      assert index_live
             |> form("#announcement-form", announcement: @invalid_attrs)
             |> render_submit() =~ "can&#39;t be blank"

      assert index_live
             |> form("#announcement-form", announcement: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/announcements")

      html = render(index_live)
      assert html =~ "Announcement created successfully"
      assert html =~ "some title"
    end

    @tag create_org: true
    test "updates announcement in listing", %{conn: conn, announcement: announcement} do
      {:ok, index_live, _html} = live(conn, ~p"/announcements")

      assert index_live
             |> element("#announcements-#{announcement.id} a", "Edit")
             |> render_click() =~
               "Edit"

      assert_patch(index_live, ~p"/announcements/#{announcement}/edit")

      assert index_live
             |> form("#announcement-form", announcement: @invalid_attrs)
             |> render_submit() =~ "can&#39;t be blank"

      assert index_live
             |> form("#announcement-form", announcement: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/announcements")

      html = render(index_live)
      assert html =~ "Announcement updated successfully"
      assert html =~ "some updated title"
    end

    @tag create_org: true
    test "deletes announcement in listing", %{conn: conn, announcement: announcement} do
      {:ok, index_live, _html} = live(conn, ~p"/announcements")

      assert index_live
             |> element("#announcements-#{announcement.id} a", "Delete")
             |> render_click()

      refute has_element?(index_live, "#announcements-#{announcement.id}")
    end
  end

  describe "Show" do
    setup [:register_and_log_in_user]

    setup %{user: user, org: org} do
      announcement = announcement_fixture(user, org)
      %{announcement: announcement}
    end

    @tag create_org: true
    test "displays announcement", %{conn: conn, announcement: announcement} do
      {:ok, _show_live, html} = live(conn, ~p"/announcements/#{announcement}")

      assert html =~ "Show Announcement"
      assert html =~ announcement.title
    end

    @tag create_org: true
    test "updates announcement within modal", %{conn: conn, announcement: announcement} do
      {:ok, show_live, _html} = live(conn, ~p"/announcements/#{announcement}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Announcement"

      assert_patch(show_live, ~p"/announcements/#{announcement}/show/edit")

      assert show_live
             |> form("#announcement-form", announcement: @invalid_attrs)
             |> render_submit() =~ "can&#39;t be blank"

      assert show_live
             |> form("#announcement-form", announcement: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/announcements/#{announcement}")

      html = render(show_live)
      assert html =~ "Announcement updated successfully"
      assert html =~ "some updated title"
    end
  end
end
