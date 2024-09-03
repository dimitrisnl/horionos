defmodule Horionos.AnnouncementsTest do
  use Horionos.DataCase

  alias Horionos.Announcements
  alias Horionos.Announcements.Announcement
  import Horionos.AnnouncementsFixtures
  import Horionos.OrganizationsFixtures

  describe "announcements" do
    setup do
      organization = organization_fixture()
      %{organization: organization}
    end

    test "list_announcements/1 returns all announcements for an organization", %{
      organization: organization
    } do
      announcement1 = announcement_fixture(organization)
      :timer.sleep(1000)
      announcement2 = announcement_fixture(organization)

      announcements = Announcements.list_announcements(organization)
      assert length(announcements) == 2
      assert Enum.map(announcements, & &1.id) == [announcement2.id, announcement1.id]
    end

    test "list_announcements/1 returns empty list when no announcements", %{
      organization: organization
    } do
      assert [] == Announcements.list_announcements(organization)
    end

    test "get_announcement/2 returns the announcement with given id", %{
      organization: organization
    } do
      announcement = announcement_fixture(organization)

      assert {:ok, fetched_announcement} =
               Announcements.get_announcement(organization, announcement.id)

      assert fetched_announcement.id == announcement.id
    end

    test "get_announcement/2 returns error for non-existent announcement", %{
      organization: organization
    } do
      assert {:error, :not_found} = Announcements.get_announcement(organization, -1)
    end

    test "create_announcement/2 with valid data creates an announcement", %{
      organization: organization
    } do
      valid_attrs = valid_announcement_attributes()

      assert {:ok, %Announcement{} = announcement} =
               Announcements.create_announcement(organization, valid_attrs)

      assert announcement.body == valid_attrs.body
      assert announcement.title == valid_attrs.title
      assert announcement.organization_id == organization.id
    end

    test "create_announcement/2 with very long title and body", %{organization: organization} do
      long_title = String.duplicate("a", 256)
      long_body = String.duplicate("b", 10_001)

      attrs = %{title: long_title, body: long_body, organization_id: organization.id}
      assert {:error, changeset} = Announcements.create_announcement(organization, attrs)

      assert "should be at most 255 character(s)" in errors_on(changeset).title
      assert "should be at most 10000 character(s)" in errors_on(changeset).body
    end

    test "create_announcement/2 with invalid data returns error changeset", %{
      organization: organization
    } do
      assert {:error, %Ecto.Changeset{}} = Announcements.create_announcement(organization, %{})
    end

    test "update_announcement/2 with valid data updates the announcement", %{
      organization: organization
    } do
      announcement = announcement_fixture(organization)
      update_attrs = %{body: "updated body", title: "updated title"}

      assert {:ok, %Announcement{} = updated} =
               Announcements.update_announcement(announcement, update_attrs)

      assert updated.body == "updated body"
      assert updated.title == "updated title"
    end

    test "update_announcement/2 with invalid data returns error changeset", %{
      organization: organization
    } do
      announcement = announcement_fixture(organization)

      assert {:error, %Ecto.Changeset{}} =
               Announcements.update_announcement(announcement, %{title: nil})

      assert {:ok, %Announcement{}} =
               Announcements.get_announcement(organization, announcement.id)
    end

    test "delete_announcement/1 deletes the announcement", %{organization: organization} do
      announcement = announcement_fixture(organization)
      assert {:ok, %Announcement{}} = Announcements.delete_announcement(announcement)
      assert {:error, :not_found} = Announcements.get_announcement(organization, announcement.id)
    end

    test "build_announcement_changeset/1 returns an announcement changeset", %{
      organization: organization
    } do
      announcement = announcement_fixture(organization)
      assert %Ecto.Changeset{} = Announcements.build_announcement_changeset(announcement)
    end
  end

  describe "announcements across organizations" do
    test "announcements are properly scoped to their organizations" do
      org1 = organization_fixture()
      org2 = organization_fixture()

      announcement1 = announcement_fixture(org1)
      announcement2 = announcement_fixture(org2)

      assert [fetched1] = Announcements.list_announcements(org1)
      assert [fetched2] = Announcements.list_announcements(org2)
      assert fetched1.id == announcement1.id
      assert fetched2.id == announcement2.id

      assert {:ok, ^announcement1} = Announcements.get_announcement(org1, announcement1.id)
      assert {:error, :not_found} = Announcements.get_announcement(org1, announcement2.id)
      assert {:error, :not_found} = Announcements.get_announcement(org2, announcement1.id)
      assert {:ok, ^announcement2} = Announcements.get_announcement(org2, announcement2.id)
    end
  end
end
