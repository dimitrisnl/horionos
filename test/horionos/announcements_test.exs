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
      OrgsFixtures.membership_fixture(owner, %{user_id: admin.id, org_id: org.id, role: :admin})
      OrgsFixtures.membership_fixture(owner, %{user_id: member.id, org_id: org.id, role: :member})

      %{owner: owner, admin: admin, member: member, non_member: non_member, org: org}
    end

    test "list_announcements/2 returns all announcements for an org", %{admin: admin, org: org} do
      announcement1 = AnnouncementsFixtures.announcement_fixture(admin, org)
      announcement2 = AnnouncementsFixtures.announcement_fixture(admin, org)

      assert {:ok, announcements} = Announcements.list_announcements(admin, org.id)
      assert length(announcements) == 2
      assert Enum.map(announcements, & &1.id) == [announcement1.id, announcement2.id]
    end

    test "list_announcements/2 returns empty list when no announcements", %{
      member: member,
      org: org
    } do
      assert {:ok, []} = Announcements.list_announcements(member, org.id)
    end

    test "list_announcements/2 returns error for non-member", %{non_member: non_member, org: org} do
      assert {:error, :unauthorized} = Announcements.list_announcements(non_member, org.id)
    end

    test "get_announcement/3 returns the announcement with given id", %{member: member, org: org} do
      announcement = AnnouncementsFixtures.announcement_fixture(member, org)

      assert {:ok, %Announcement{}} =
               Announcements.get_announcement(member, announcement.id, org.id)
    end

    test "get_announcement/3 returns error for non-existent announcement", %{
      member: member,
      org: org
    } do
      assert {:error, :not_found} = Announcements.get_announcement(member, -1, org.id)
    end

    test "get_announcement/3 returns error for non-member", %{
      member: member,
      non_member: non_member,
      org: org
    } do
      announcement = AnnouncementsFixtures.announcement_fixture(member, org)

      assert {:error, :unauthorized} =
               Announcements.get_announcement(non_member, announcement.id, org.id)
    end

    test "create_announcement/3 with valid data creates an announcement", %{
      admin: admin,
      org: org
    } do
      valid_attrs = %{body: "some body", title: "some title", org_id: org.id}

      assert {:ok, %Announcement{} = announcement} =
               Announcements.create_announcement(admin, org.id, valid_attrs)

      assert announcement.body == "some body"
      assert announcement.title == "some title"
      assert announcement.org_id == org.id
    end

    test "create_announcement/3 with invalid data returns error changeset", %{
      admin: admin,
      org: org
    } do
      assert {:error, %Ecto.Changeset{}} = Announcements.create_announcement(admin, org.id, %{})
    end

    test "create_announcement/3 fails for non-member user", %{non_member: non_member, org: org} do
      valid_attrs = %{body: "some body", title: "some title"}

      assert {:error, :unauthorized} =
               Announcements.create_announcement(non_member, org.id, valid_attrs)
    end

    test "update_announcement/3 with valid data updates the announcement", %{
      admin: admin,
      org: org
    } do
      announcement = AnnouncementsFixtures.announcement_fixture(admin, org)
      update_attrs = %{body: "updated body", title: "updated title"}

      assert {:ok, %Announcement{} = updated} =
               Announcements.update_announcement(admin, announcement, update_attrs)

      assert updated.body == "updated body"
      assert updated.title == "updated title"
    end

    test "update_announcement/3 with invalid data returns error changeset", %{
      admin: admin,
      org: org
    } do
      announcement = AnnouncementsFixtures.announcement_fixture(admin, org)

      assert {:error, %Ecto.Changeset{}} =
               Announcements.update_announcement(admin, announcement, %{title: nil})

      assert {:ok, %Announcement{}} =
               Announcements.get_announcement(admin, announcement.id, org.id)
    end

    test "update_announcement/3 fails for non-user user", %{
      non_member: non_member,
      member: member,
      org: org
    } do
      announcement = AnnouncementsFixtures.announcement_fixture(member, org)
      update_attrs = %{body: "updated body"}

      assert {:error, :unauthorized} =
               Announcements.update_announcement(non_member, announcement, update_attrs)
    end

    test "delete_announcement/2 deletes the announcement", %{admin: admin, org: org} do
      announcement = AnnouncementsFixtures.announcement_fixture(admin, org)
      assert {:ok, %Announcement{}} = Announcements.delete_announcement(admin, announcement)
      assert {:error, :not_found} = Announcements.get_announcement(admin, announcement.id, org.id)
    end

    test "delete_announcement/2 fails for non-admin user", %{
      non_member: non_member,
      member: member,
      org: org
    } do
      announcement = AnnouncementsFixtures.announcement_fixture(member, org)
      assert {:error, :unauthorized} = Announcements.delete_announcement(non_member, announcement)
    end

    test "build_announcement_changeset/1 returns a announcement changeset", %{admin: admin, org: org} do
      announcement = AnnouncementsFixtures.announcement_fixture(admin, org)
      assert %Ecto.Changeset{} = Announcements.build_announcement_changeset(announcement)
    end

    test "create_announcement/3 with very long title and body", %{admin: admin, org: org} do
      long_title = String.duplicate("a", 256)
      long_body = String.duplicate("b", 10_001)
      attrs = %{title: long_title, body: long_body, org_id: org.id}
      assert {:error, changeset} = Announcements.create_announcement(admin, org.id, attrs)
      assert "should be at most 255 character(s)" in errors_on(changeset).title
      assert "should be at most 10000 character(s)" in errors_on(changeset).body
    end

    test "list_announcements/2 returns announcements in descending order of insertion", %{
      admin: admin,
      org: org
    } do
      announcement1 =
        AnnouncementsFixtures.announcement_fixture(admin, org, %{org_id: org.id, title: "First"})

      :timer.sleep(1000)

      announcement2 =
        AnnouncementsFixtures.announcement_fixture(admin, org, %{org_id: org.id, title: "Second"})

      assert {:ok, [^announcement2, ^announcement1]} =
               Announcements.list_announcements(admin, org.id)
    end

    test "get_announcement/3 returns error for announcement from different org", %{
      admin: admin,
      org: org
    } do
      other_org = OrgsFixtures.org_fixture(%{user: admin})

      announcement =
        AnnouncementsFixtures.announcement_fixture(admin, other_org, %{org_id: other_org.id})

      assert {:error, :not_found} = Announcements.get_announcement(admin, announcement.id, org.id)
    end
  end
end
