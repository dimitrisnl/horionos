defmodule Horionos.MembershipTests do
  use Horionos.DataCase, async: true

  import Horionos.AccountsFixtures
  import Horionos.OrganizationsFixtures
  import Horionos.MembershipsFixtures

  alias Horionos.Memberships.Memberships
  alias Horionos.Memberships.Schemas.Membership
  alias Horionos.Repo

  describe "list_user_memberships/1" do
    test "returns all memberships for a given user" do
      owner = user_fixture()
      organization1 = organization_fixture(%{user: owner})
      organization2 = organization_fixture(%{user: owner})

      assert {:ok, memberships} = Memberships.list_user_memberships(owner)
      assert length(memberships) == 2

      assert Enum.all?(memberships, fn membership ->
               membership.organization.id in [organization1.id, organization2.id]
             end)
    end

    test "returns an empty list for a user with no organizations" do
      user = user_fixture()
      assert {:ok, []} = Memberships.list_user_memberships(user)
    end
  end

  describe "list_organization_memberships/1" do
    setup do
      owner = user_fixture()
      member = user_fixture()
      organization = organization_fixture(%{user: owner})
      membership_fixture(%{user_id: member.id, organization_id: organization.id, role: :member})
      %{organization: organization}
    end

    test "returns memberships", %{organization: organization} do
      assert {:ok, memberships} = Memberships.list_organization_memberships(organization)
      # owner and member
      assert length(memberships) == 2
    end
  end

  describe "create_membership/1" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})
      %{organization: organization}
    end

    test "creates a membership", %{organization: organization} do
      new_user = user_fixture()
      attrs = %{user_id: new_user.id, organization_id: organization.id, role: :member}

      assert {:ok, %Membership{} = membership} = Memberships.create_membership(attrs)
      assert membership.user_id == new_user.id
      assert membership.organization_id == organization.id
      assert membership.role == :member
    end
  end

  describe "update_membership_role/2" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})
      user = user_fixture()

      membership =
        membership_fixture(%{user_id: user.id, organization_id: organization.id, role: :member})

      %{membership: membership}
    end

    test "updates the membership when user has permissions", %{membership: membership} do
      update_attrs = %{role: :admin}

      assert {:ok, %Membership{} = updated_membership} =
               Memberships.update_membership_role(membership, update_attrs)

      assert updated_membership.role == :admin
    end

    test "returns an error changeset with invalid data", %{membership: membership} do
      assert {:error, %Ecto.Changeset{}} =
               Memberships.update_membership_role(membership, %{role: :invalid_role})
    end
  end

  describe "delete_membership/1" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})
      user = user_fixture()

      membership =
        membership_fixture(%{user_id: user.id, organization_id: organization.id, role: :member})

      %{membership: membership, user: user}
    end

    test "deletes the membership when user has permissions", %{membership: membership, user: user} do
      assert {:ok, %Membership{}} = Memberships.delete_membership(membership)

      assert Membership
             |> Repo.all()
             |> Enum.filter(&(&1.user_id == user.id))
             |> Enum.empty?()
    end
  end

  describe "get_user_role/2" do
    setup do
      owner = user_fixture()
      member = user_fixture()
      organization = organization_fixture(%{user: owner})
      membership_fixture(%{user_id: member.id, organization_id: organization.id, role: :member})
      %{owner: owner, member: member, organization: organization}
    end

    test "returns the correct role for a user", %{
      owner: owner,
      member: member,
      organization: organization
    } do
      assert {:ok, :owner} = Memberships.get_user_role(owner, organization)
      assert {:ok, :member} = Memberships.get_user_role(member, organization)
    end

    test "returns error for a user not in the organization", %{organization: organization} do
      non_member = user_fixture()
      assert {:error, :role_not_found} = Memberships.get_user_role(non_member, organization)
    end
  end

  describe "user_in_organization?/2" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})
      %{owner: owner, organization: organization}
    end

    test "returns true when user is in organization", %{owner: owner, organization: organization} do
      assert Memberships.user_in_organization?(organization, owner.email)
    end

    test "returns false when user is not in organization", %{organization: organization} do
      non_member = user_fixture()
      refute Memberships.user_in_organization?(organization, non_member.email)
    end
  end

  describe "user_has_any_membership?/1" do
    test "returns true when user has memberships" do
      owner = user_fixture()
      organization_fixture(%{user: owner})
      assert Memberships.user_has_any_membership?(owner.email)
    end

    test "returns false when user has no memberships" do
      user = user_fixture()
      refute Memberships.user_has_any_membership?(user.email)
    end
  end

  describe "get_user_primary_organization/1" do
    test "returns the first organization a user joined" do
      owner = user_fixture()
      organization1 = organization_fixture(%{user: owner})
      organization2 = organization_fixture(%{user: owner})

      assert Memberships.get_user_primary_organization(owner).id == organization1.id
      refute Memberships.get_user_primary_organization(owner).id == organization2.id
    end

    test "returns nil when user has no organizations" do
      user = user_fixture()
      assert Memberships.get_user_primary_organization(user) == nil
    end
  end
end
