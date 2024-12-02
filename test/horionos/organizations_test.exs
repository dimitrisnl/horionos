defmodule Horionos.OrganizationsTest do
  use Horionos.DataCase, async: true

  import Horionos.AccountsFixtures
  import Horionos.OrganizationsFixtures
  import Horionos.MembershipsFixtures
  import Horionos.InvitationsFixtures

  alias Horionos.Invitations.Schemas.Invitation
  alias Horionos.Memberships.Schemas.Membership
  alias Horionos.Organizations.Organizations
  alias Horionos.Organizations.Schemas.Organization
  alias Horionos.Repo

  describe "get_organization/1" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})
      %{owner: owner, organization: organization}
    end

    test "returns the organization", %{organization: organization} do
      assert {:ok, ^organization} = Organizations.get_organization(organization.id)
    end

    test "returns error for non-existent organization" do
      assert {:error, :not_found} = Organizations.get_organization(-1)
    end
  end

  describe "create_organization/2" do
    setup do
      %{user: user_fixture()}
    end

    test "creates an organization and adds the user as an owner", %{user: user} do
      attrs = %{title: "Test Organization"}

      assert {:ok, %Organization{} = organization} =
               Organizations.create_organization(user, attrs)

      assert organization.title == "Test Organization"

      assert %Membership{role: :owner} =
               Repo.get_by(Membership, user_id: user.id, organization_id: organization.id)
    end

    test "returns an error changeset with invalid data", %{user: user} do
      assert {:error, %Ecto.Changeset{}} = Organizations.create_organization(user, %{title: nil})
    end
  end

  describe "update_organization/2" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})
      %{organization: organization}
    end

    test "updates the organization when user has permissions", %{organization: organization} do
      update_attrs = %{title: "Updated Organization"}

      assert {:ok, %Organization{} = updated_organization} =
               Organizations.update_organization(organization, update_attrs)

      assert updated_organization.title == "Updated Organization"
    end

    test "returns an error changeset with invalid data", %{organization: organization} do
      assert {:error, %Ecto.Changeset{}} =
               Organizations.update_organization(organization, %{title: nil})
    end
  end

  describe "delete_organization/1" do
    setup do
      organization = organization_fixture(%{user: user_fixture()})
      %{organization: organization}
    end

    test "deletes the organization", %{organization: organization} do
      assert {:ok, %Organization{}} = Organizations.delete_organization(organization)
      assert {:error, :not_found} = Organizations.get_organization(organization.id)
    end
  end

  describe "build_organization_changeset/2" do
    test "returns a valid organization changeset" do
      organization = organization_fixture()
      attrs = %{title: "New Organization Title"}
      changeset = Organizations.build_organization_changeset(organization, attrs)
      assert changeset.valid?
      assert get_change(changeset, :title) == "New Organization Title"
    end

    test "returns an invalid organization changeset with invalid data" do
      organization = organization_fixture()
      attrs = %{title: nil}
      changeset = Organizations.build_organization_changeset(organization, attrs)
      refute changeset.valid?
    end
  end

  describe "edge cases" do
    test "deleting an organization cascades to memberships and invitations" do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})
      user1 = user_fixture()
      user2 = user_fixture()

      membership_fixture(%{user_id: user1.id, organization_id: organization.id, role: :member})
      membership_fixture(%{user_id: user2.id, organization_id: organization.id, role: :member})

      invitation_fixture(owner, organization, "test1@example.com", :member)
      invitation_fixture(owner, organization, "test2@example.com", :member)

      # Delete organization
      assert {:ok, _} = Organizations.delete_organization(organization)

      # Check that memberships are deleted
      assert Repo.all(Membership) == []

      # Check that invitations are deleted
      assert Repo.all(Invitation) == []
    end
  end
end
