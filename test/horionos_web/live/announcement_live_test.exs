defmodule HorionosWeb.AnnouncementLiveTest do
  use HorionosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Horionos.OrgsFixtures
  import Horionos.AnnouncementsFixtures

  alias Horionos.Announcements

  @create_attrs %{title: "some title", body: "some body"}
  @update_attrs %{title: "some updated title", body: "some updated body"}
  @invalid_attrs %{title: nil, body: nil}

  describe "Announcement" do
    setup [:register_and_log_in_user]

    setup %{user: user} do
      org = org_fixture(%{user: user})
      other_org = org_fixture(%{user: user})
      %{user: user, org: org, other_org: other_org}
    end

    test "lists only announcements for the current org", %{
      conn: conn,
      org: org,
      other_org: other_org
    } do
      announcement1 = announcement_fixture(org)
      announcement2 = announcement_fixture(org)
      other_announcement = announcement_fixture(other_org)

      {:ok, _lv, html} = live(conn, ~p"/announcements")

      assert html =~ "Listing Announcements"
      assert html =~ announcement1.title
      assert html =~ announcement2.title
      refute html =~ other_announcement.title
    end

    test "creates announcement and persists it in the current org", %{
      conn: conn,
      org: org,
      other_org: other_org
    } do
      {:ok, lv, _html} = live(conn, ~p"/announcements")

      assert lv |> element("a", "New Announcement") |> render_click() =~
               "New Announcement"

      assert_patch(lv, ~p"/announcements/new")

      assert lv
             |> form("#announcement-form", announcement: @invalid_attrs)
             |> render_submit() =~ "can&#39;t be blank"

      assert lv
             |> form("#announcement-form", announcement: @create_attrs)
             |> render_submit()

      assert_patch(lv, ~p"/announcements")
      html = render(lv)

      assert html =~ "Announcement created successfully"
      assert html =~ "some title"

      # Verify the announcement is in the current org
      announcements = Announcements.list_announcements(org)
      assert length(announcements) == 1
      [announcement] = announcements
      assert announcement.title == "some title"
      assert announcement.org_id == org.id

      # Verify the announcement is not in the other org
      assert Announcements.list_announcements(other_org) == []
    end

    test "updates announcement within the current org", %{
      conn: conn,
      org: org,
      other_org: other_org
    } do
      announcement = announcement_fixture(org)

      {:ok, lv, _html} = live(conn, ~p"/announcements")

      assert lv
             |> element("#announcements-#{announcement.id} a", "Edit")
             |> render_click() =~
               "Edit Announcement"

      assert_patch(lv, ~p"/announcements/#{announcement}/edit")

      assert lv
             |> form("#announcement-form", announcement: @invalid_attrs)
             |> render_submit() =~ "can&#39;t be blank"

      assert lv
             |> form("#announcement-form", announcement: @update_attrs)
             |> render_submit()

      assert_patch(lv, ~p"/announcements")
      html = render(lv)

      assert html =~ "Announcement updated successfully"
      assert html =~ "some updated title"

      # Verify the update is persisted in the current org
      {:ok, updated_announcement} = Announcements.get_announcement(org, announcement.id)
      assert updated_announcement.title == "some updated title"
      assert updated_announcement.org_id == org.id

      # Verify no changes in the other org
      assert Announcements.list_announcements(other_org) == []
    end

    test "deletes announcement from the current org", %{
      conn: conn,
      org: org,
      other_org: other_org
    } do
      announcement = announcement_fixture(org)
      other_announcement = announcement_fixture(other_org)

      {:ok, lv, _html} = live(conn, ~p"/announcements")

      assert lv
             |> element("#announcements-#{announcement.id} a", "Delete")
             |> render_click()

      refute has_element?(lv, "#announcement-#{announcement.id}")

      # Verify the announcement is deleted from the current org
      assert {:error, :not_found} = Announcements.get_announcement(org, announcement.id)

      # Verify the other org's announcement is untouched
      assert {:ok, _} = Announcements.get_announcement(other_org, other_announcement.id)
    end

    test "displays announcement for the current org", %{
      conn: conn,
      org: org,
      other_org: other_org
    } do
      announcement = announcement_fixture(org)
      other_announcement = announcement_fixture(other_org)

      # Can view announcement from current org
      {:ok, _show_live, html} = live(conn, ~p"/announcements/#{announcement}")
      assert html =~ "Show Announcement"
      assert html =~ announcement.title

      # Cannot view announcement from other org
      assert {:error,
              {:live_redirect,
               %{to: "/announcements", flash: %{"error" => "Announcement not found."}}}} =
               live(conn, ~p"/announcements/#{other_announcement}")
    end

    test "updates announcement within modal for the current org", %{
      conn: conn,
      org: org,
      other_org: other_org
    } do
      announcement = announcement_fixture(org)

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

      # Verify the update is persisted in the current org
      {:ok, updated_announcement} = Announcements.get_announcement(org, announcement.id)
      assert updated_announcement.title == "some updated title"
      assert updated_announcement.org_id == org.id

      # Verify no changes in the other org
      assert Announcements.list_announcements(other_org) == []
    end

    test "renders errors when trying to access non-existent announcement", %{conn: conn} do
      {:error,
       {:live_redirect, %{to: "/announcements", flash: %{"error" => "Announcement not found."}}}} =
        live(conn, ~p"/announcements/9999")
    end
  end
end
