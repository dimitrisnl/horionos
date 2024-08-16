defmodule Horionos.OrgsTest do
  use Horionos.DataCase

  alias Horionos.Orgs
  alias Horionos.Orgs.{Membership, Org}

  import Horionos.AccountsFixtures
  import Horionos.OrgsFixtures

  require Logger

  describe "list_user_orgs/1" do
    test "returns all organizations for a given user" do
      owner = user_fixture()
      org1 = org_fixture(%{user: owner})
      org2 = org_fixture(%{user: owner})

      user_orgs = Orgs.list_user_orgs(owner)
      assert length(user_orgs) == 2
      assert Enum.all?(user_orgs, fn org -> org.id in [org1.id, org2.id] end)
    end

    test "returns an empty list for a user with no organizations" do
      user = user_fixture()
      assert Orgs.list_user_orgs(user) == []
    end
  end

  describe "get_org/2" do
    test "returns the org for a user with access" do
      owner = user_fixture()
      user = user_fixture()
      org = org_fixture(%{user: owner})
      membership_fixture(owner, %{user_id: user.id, org_id: org.id, role: :member})

      assert Orgs.get_org(user, org.id) == {:ok, org}
    end

    test "returns nil for a user without access" do
      user = user_fixture()
      org = org_fixture()

      assert Orgs.get_org(user, org.id) == {:error, :unauthorized}
    end
  end

  describe "create_org/2" do
    test "creates an org and adds the user as an owner" do
      user = user_fixture()
      attrs = %{title: "Test Org"}

      assert {:ok, %Org{} = org} = Orgs.create_org(user, attrs)
      assert org.title == "Test Org"

      membership = Repo.get_by(Membership, user_id: user.id, org_id: org.id)
      assert membership.role == :owner
    end

    test "returns an error changeset with invalid data" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Orgs.create_org(user, %{title: nil})
    end
  end

  describe "update_org/3" do
    setup do
      owner = user_fixture()
      org = org_fixture(%{user: owner})
      %{owner: owner, org: org}
    end

    test "updates the org when user has permissions", %{owner: owner, org: org} do
      update_attrs = %{title: "Updated Org"}
      assert {:ok, %Org{} = updated_org} = Orgs.update_org(owner, org, update_attrs)
      assert updated_org.title == "Updated Org"
    end

    test "returns an error when user doesn't have permissions", %{org: org} do
      non_member = user_fixture()
      update_attrs = %{title: "Updated Org"}
      assert {:error, :unauthorized} = Orgs.update_org(non_member, org, update_attrs)
    end

    test "returns an error changeset with invalid data", %{owner: owner, org: org} do
      assert {:error, %Ecto.Changeset{}} = Orgs.update_org(owner, org, %{title: nil})
    end
  end

  describe "delete_org/2" do
    setup do
      owner = user_fixture()
      org = org_fixture(%{user: owner})
      %{owner: owner, org: org}
    end

    test "deletes the org when user is owner", %{owner: owner, org: org} do
      assert {:ok, %Org{}} = Orgs.delete_org(owner, org)
      assert Orgs.get_org(owner, org.id) == {:error, :unauthorized}
    end

    test "returns an error when user is not owner", %{org: org, owner: owner} do
      non_owner = user_fixture()
      membership_fixture(owner, %{user_id: non_owner.id, org_id: org.id, role: :admin})
      assert {:error, :unauthorized} = Orgs.delete_org(non_owner, org)
    end
  end

  describe "create_membership/2" do
    setup do
      owner = user_fixture()
      admin = user_fixture()
      member = user_fixture()
      org = org_fixture(%{user: owner})
      membership_fixture(owner, %{user_id: admin.id, org_id: org.id, role: :admin})
      membership_fixture(owner, %{user_id: member.id, org_id: org.id, role: :member})
      %{admin: admin, member: member, org: org}
    end

    test "creates a membership when user has permissions", %{admin: admin, org: org} do
      new_user = user_fixture()
      attrs = %{user_id: new_user.id, org_id: org.id, role: :member}

      assert {:ok, %Membership{} = membership} = Orgs.create_membership(admin, attrs)
      assert membership.user_id == new_user.id
      assert membership.org_id == org.id
      assert membership.role == :member
    end

    test "returns an error when user is a member", %{member: member, org: org} do
      new_user = user_fixture()
      attrs = %{user_id: new_user.id, org_id: org.id, role: :member}

      assert {:error, :unauthorized} = Orgs.create_membership(member, attrs)
    end

    test "returns an error when user doesn't have permissions", %{org: org} do
      non_admin = user_fixture()
      new_user = user_fixture()
      attrs = %{user_id: new_user.id, org_id: org.id, role: :member}

      assert {:error, :unauthorized} = Orgs.create_membership(non_admin, attrs)
    end
  end

  describe "update_membership/3" do
    setup do
      owner = user_fixture()
      admin = user_fixture()
      member = user_fixture()
      user = user_fixture()

      org = org_fixture(%{user: owner})

      membership_fixture(owner, %{user_id: admin.id, org_id: org.id, role: :admin})
      membership_fixture(owner, %{user_id: member.id, org_id: org.id, role: :member})
      membership_fixture(owner, %{user_id: user.id, org_id: org.id, role: :member})

      %{member: member, admin: admin, user: user, org: org}
    end

    test "updates the membership when user has permissions", %{user: user, admin: admin, org: org} do
      membership = Repo.get_by(Membership, user_id: user.id, org_id: org.id)
      update_attrs = %{role: :admin}

      assert {:ok, %Membership{} = updated_membership} =
               Orgs.update_membership(admin, membership, update_attrs)

      assert updated_membership.role == :admin
    end

    test "returns an error when user doesn't have permissions as member", %{
      user: user,
      member: member,
      org: org
    } do
      membership = Repo.get_by!(Membership, user_id: user.id, org_id: org.id)
      update_attrs = %{role: :admin}

      assert {:error, :unauthorized} = Orgs.update_membership(member, membership, update_attrs)
    end

    test "returns an error when user doesn't have permissions", %{user: user, org: org} do
      non_admin = user_fixture()
      membership = Repo.get_by!(Membership, user_id: user.id, org_id: org.id)
      update_attrs = %{role: :admin}

      assert {:error, :unauthorized} = Orgs.update_membership(non_admin, membership, update_attrs)
    end
  end

  describe "delete_membership/2" do
    setup do
      owner = user_fixture()
      admin = user_fixture()
      member = user_fixture()
      user = user_fixture()

      org = org_fixture(%{user: owner})

      membership_fixture(owner, %{user_id: admin.id, org_id: org.id, role: :admin})
      membership_fixture(owner, %{user_id: member.id, org_id: org.id, role: :member})
      membership_fixture(owner, %{user_id: user.id, org_id: org.id, role: :member})

      %{member: member, admin: admin, user: user, org: org}
    end

    test "deletes the membership when user has permissions", %{user: user, admin: admin, org: org} do
      membership = Repo.get_by!(Membership, user_id: user.id, org_id: org.id)

      assert {:ok, %Membership{}} = Orgs.delete_membership(admin, membership)
      assert is_nil(Repo.get_by(Membership, user_id: user.id, org_id: org.id))
    end

    test "returns an error when user doesn't have permissions as member", %{
      user: user,
      member: member,
      org: org
    } do
      membership = Repo.get_by!(Membership, user_id: user.id, org_id: org.id)

      assert {:error, :unauthorized} = Orgs.delete_membership(member, membership)
    end

    test "returns an error when user doesn't have permissions", %{
      user: user,
      org: org
    } do
      non_admin = user_fixture()
      membership = Repo.get_by!(Membership, user_id: user.id, org_id: org.id)

      assert {:error, :unauthorized} = Orgs.delete_membership(non_admin, membership)
    end
  end

  describe "authorize_user/3" do
    setup do
      owner = user_fixture()
      admin = user_fixture()
      org = org_fixture(%{user: owner})
      membership_fixture(owner, %{user_id: admin.id, org_id: org.id, role: :admin})
      %{admin: admin, org: org}
    end

    test "returns :ok when user has required role", %{admin: admin, org: org} do
      assert :ok = Orgs.authorize_user(admin, org, :member)
      assert :ok = Orgs.authorize_user(admin, org, :admin)
    end

    test "returns error when user doesn't have required role", %{admin: admin, org: org} do
      assert {:error, :unauthorized} = Orgs.authorize_user(admin, org, :owner)
    end

    test "returns error for non-member user", %{org: org} do
      non_member = user_fixture()
      assert {:error, :unauthorized} = Orgs.authorize_user(non_member, org, :member)
    end
  end

  describe "user_has_any_membership?/1" do
    test "returns true when user has memberships" do
      owner = user_fixture()
      org_fixture(%{user: owner})

      assert Orgs.user_has_any_membership?(owner)
    end

    test "returns false when user has no memberships" do
      user = user_fixture()
      refute Orgs.user_has_any_membership?(user)
    end
  end

  describe "get_user_primary_org/1" do
    test "returns the first org a user joined" do
      owner = user_fixture()
      org1 = org_fixture(%{user: owner})
      org_fixture(%{user: owner})

      assert Orgs.get_user_primary_org(owner).id == org1.id
    end

    test "returns nil when user has no orgs" do
      user = user_fixture()
      assert Orgs.get_user_primary_org(user) == nil
    end
  end

  describe "build_org_changeset/2" do
    test "returns a org changeset" do
      org = org_fixture()
      assert %Ecto.Changeset{} = changeset = Orgs.build_org_changeset(org)
      assert changeset.valid?
    end
  end
end
