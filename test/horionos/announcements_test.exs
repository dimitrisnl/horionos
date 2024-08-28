defmodule Horionos.AnnouncementsTest do
  use Horionos.DataCase

  alias Horionos.AccountsFixtures
  alias Horionos.Announcements
  alias Horionos.Announcements.Announcement
  alias Horionos.AnnouncementsFixtures
  alias Horionos.OrgsFixtures

  describe "announcements" do
    setup do
      owner = AccountsFixtures.user_fixture()
      admin = AccountsFixtures.user_fixture()
      member = AccountsFixtures.user_fixture()
      non_member = AccountsFixtures.user_fixture()

      org = OrgsFixtures.org_fixture(%{user: owner})
      OrgsFixtures.membership_fixture(%{user_id: admin.id, org_id: org.id, role: :admin})
      OrgsFixtures.membership_fixture(%{user_id: member.id, org_id: org.id, role: :member})

      %{owner: owner, admin: admin, member: member, non_member: non_member, org: org}
    end

    test "list_announcements/1 returns all announcements for an org", %{org: org} do
      announcement1 = AnnouncementsFixtures.announcement_fixture(org)
      # Ensure a difference in inserted_at timestamps
      :timer.sleep(1000)
      announcement2 = AnnouncementsFixtures.announcement_fixture(org)

      announcements = Announcements.list_announcements(org)
      assert length(announcements) == 2
      assert Enum.map(announcements, & &1.id) == [announcement2.id, announcement1.id]
    end

    test "list_announcements/1 returns empty list when no announcements", %{org: org} do
      assert [] == Announcements.list_announcements(org)
    end

    test "get_announcement/2 returns the announcement with given id", %{org: org} do
      announcement = AnnouncementsFixtures.announcement_fixture(org)
      assert {:ok, %Announcement{}} = Announcements.get_announcement(org, announcement.id)
    end

    test "get_announcement/2 returns error for non-existent announcement", %{org: org} do
      assert {:error, :not_found} = Announcements.get_announcement(org, -1)
    end

    test "create_announcement/2 with valid data creates an announcement", %{org: org} do
      valid_attrs = %{body: "some body", title: "some title", org_id: org.id}

      assert {:ok, %Announcement{} = announcement} =
               Announcements.create_announcement(org, valid_attrs)

      assert announcement.body == "some body"
      assert announcement.title == "some title"
      assert announcement.org_id == org.id
    end

    test "create_announcement/2 with invalid data returns error changeset", %{org: org} do
      assert {:error, %Ecto.Changeset{}} = Announcements.create_announcement(org, %{})
    end

    test "update_announcement/2 with valid data updates the announcement", %{org: org} do
      announcement = AnnouncementsFixtures.announcement_fixture(org)
      update_attrs = %{body: "updated body", title: "updated title"}

      assert {:ok, %Announcement{} = updated} =
               Announcements.update_announcement(announcement, update_attrs)

      assert updated.body == "updated body"
      assert updated.title == "updated title"
    end

    test "update_announcement/2 with invalid data returns error changeset", %{org: org} do
      announcement = AnnouncementsFixtures.announcement_fixture(org)

      assert {:error, %Ecto.Changeset{}} =
               Announcements.update_announcement(announcement, %{title: nil})

      assert {:ok, %Announcement{}} = Announcements.get_announcement(org, announcement.id)
    end

    test "delete_announcement/1 deletes the announcement", %{org: org} do
      announcement = AnnouncementsFixtures.announcement_fixture(org)
      assert {:ok, %Announcement{}} = Announcements.delete_announcement(announcement)
      assert {:error, :not_found} = Announcements.get_announcement(org, announcement.id)
    end

    test "build_announcement_changeset/1 returns a announcement changeset", %{org: org} do
      announcement = AnnouncementsFixtures.announcement_fixture(org)
      assert %Ecto.Changeset{} = Announcements.build_announcement_changeset(announcement)
    end

    test "create_announcement/2 with very long title and body", %{org: org} do
      long_title = String.duplicate("a", 256)
      long_body = String.duplicate("b", 10_001)
      attrs = %{title: long_title, body: long_body, org_id: org.id}
      assert {:error, changeset} = Announcements.create_announcement(org, attrs)
      assert "should be at most 255 character(s)" in errors_on(changeset).title
      assert "should be at most 10000 character(s)" in errors_on(changeset).body
    end

    test "list_announcements/1 returns announcements in descending order of insertion", %{
      org: org
    } do
      announcement1 = AnnouncementsFixtures.announcement_fixture(org, %{title: "First"})
      :timer.sleep(1000)
      announcement2 = AnnouncementsFixtures.announcement_fixture(org, %{title: "Second"})
      assert [^announcement2, ^announcement1] = Announcements.list_announcements(org)
    end

    test "get_announcement/2 returns error for announcement from different org", %{org: org} do
      other_org = OrgsFixtures.org_fixture()
      announcement = AnnouncementsFixtures.announcement_fixture(other_org)
      assert {:error, :not_found} = Announcements.get_announcement(org, announcement.id)
    end
  end
end
