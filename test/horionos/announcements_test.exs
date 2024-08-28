defmodule Horionos.AnnouncementsTest do
  use Horionos.DataCase

  alias Horionos.Announcements
  alias Horionos.Announcements.Announcement
  import Horionos.AnnouncementsFixtures

  import Horionos.OrganizationsFixtures
  import Horionos.AccountsFixtures

  describe "announcements" do
    setup do
      owner = user_fixture()
      admin = user_fixture()
      member = user_fixture()
      non_member = user_fixture()

      organization = organization_fixture(%{user: owner})

      membership_fixture(%{
        user_id: admin.id,
        organization_id: organization.id,
        role: :admin
      })

      membership_fixture(%{
        user_id: member.id,
        organization_id: organization.id,
        role: :member
      })

      %{
        owner: owner,
        admin: admin,
        member: member,
        non_member: non_member,
        organization: organization
      }
    end

    test "list_announcements/1 returns all announcements for an organization", %{
      organization: organization
    } do
      announcement1 = announcement_fixture(organization)
      # Ensure a difference in inserted_at timestamps
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

      assert {:ok, %Announcement{}} =
               Announcements.get_announcement(organization, announcement.id)
    end

    test "get_announcement/2 returns error for non-existent announcement", %{
      organization: organization
    } do
      assert {:error, :not_found} = Announcements.get_announcement(organization, -1)
    end

    test "create_announcement/2 with valid data creates an announcement", %{
      organization: organization
    } do
      valid_attrs = %{body: "some body", title: "some title", organization_id: organization.id}

      assert {:ok, %Announcement{} = announcement} =
               Announcements.create_announcement(organization, valid_attrs)

      assert announcement.body == "some body"
      assert announcement.title == "some title"
      assert announcement.organization_id == organization.id
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

    test "build_announcement_changeset/1 returns a announcement changeset", %{
      organization: organization
    } do
      announcement = announcement_fixture(organization)
      assert %Ecto.Changeset{} = Announcements.build_announcement_changeset(announcement)
    end

    test "create_announcement/2 with very long title and body", %{organization: organization} do
      long_title = String.duplicate("a", 256)
      long_body = String.duplicate("b", 10_001)
      attrs = %{title: long_title, body: long_body, organization_id: organization.id}
      assert {:error, changeset} = Announcements.create_announcement(organization, attrs)
      assert "should be at most 255 character(s)" in errors_on(changeset).title
      assert "should be at most 10000 character(s)" in errors_on(changeset).body
    end

    test "list_announcements/1 returns announcements in descending order of insertion", %{
      organization: organization
    } do
      announcement1 = announcement_fixture(organization, %{title: "First"})
      :timer.sleep(1000)
      announcement2 = announcement_fixture(organization, %{title: "Second"})
      assert [^announcement2, ^announcement1] = Announcements.list_announcements(organization)
    end

    test "get_announcement/2 returns error for announcement from different organization", %{
      organization: organization
    } do
      other_organization = organization_fixture()
      announcement = announcement_fixture(other_organization)
      assert {:error, :not_found} = Announcements.get_announcement(organization, announcement.id)
    end
  end
end
