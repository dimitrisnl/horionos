defmodule Horionos.AuthorizationTest do
  use Horionos.DataCase

  alias Horionos.Accounts.User
  alias Horionos.Authorization
  alias Horionos.Orgs.{Membership, Org}
  alias Horionos.Repo

  describe "authorize/3" do
    setup do
      owner = user_fixture()
      admin = user_fixture()
      member = user_fixture()
      non_member = user_fixture()

      org = org_fixture(%{user: owner})

      membership_fixture(%{user_id: admin.id, org_id: org.id, role: :admin})
      membership_fixture(%{user_id: member.id, org_id: org.id, role: :member})

      %{owner: owner, admin: admin, member: member, non_member: non_member, org: org}
    end

    test "allows owner to perform owner actions", %{owner: owner, org: org} do
      assert :ok == Authorization.authorize(owner, org, :org_delete)
    end

    test "allows owner to perform admin actions", %{owner: owner, org: org} do
      assert :ok == Authorization.authorize(owner, org, :org_edit)
    end

    test "allows owner to perform member actions", %{owner: owner, org: org} do
      assert :ok == Authorization.authorize(owner, org, :org_view)
    end

    test "allows admin to perform admin actions", %{admin: admin, org: org} do
      assert :ok == Authorization.authorize(admin, org, :org_edit)
    end

    test "allows admin to perform member actions", %{admin: admin, org: org} do
      assert :ok == Authorization.authorize(admin, org, :org_view)
    end

    test "denies admin from performing owner actions", %{admin: admin, org: org} do
      assert {:error, :unauthorized} == Authorization.authorize(admin, org, :org_delete)
    end

    test "allows member to perform member actions", %{member: member, org: org} do
      assert :ok == Authorization.authorize(member, org, :org_view)
    end

    test "denies member from performing admin actions", %{member: member, org: org} do
      assert {:error, :unauthorized} == Authorization.authorize(member, org, :org_edit)
    end

    test "denies non-member from performing any action", %{non_member: non_member, org: org} do
      assert {:error, :unauthorized} == Authorization.authorize(non_member, org, :org_view)
    end

    test "handles invalid permissions", %{owner: owner, org: org} do
      assert {:error, :invalid_permission} ==
               Authorization.authorize(owner, org, :invalid_permission)
    end
  end

  describe "get_org_from_resource/1" do
    setup do
      owner = user_fixture()
      org = org_fixture(%{user: owner})
      %{org: org}
    end

    test "returns org when given an Org struct", %{org: org} do
      assert Authorization.get_org_from_resource(org) == {:ok, org}
    end

    test "returns org when given a struct with org_id", %{org: org} do
      resource = %{org_id: org.id}
      assert Authorization.get_org_from_resource(resource) == {:ok, org}
    end

    test "returns error for invalid resource" do
      assert Authorization.get_org_from_resource(%{}) == {:error, :invalid_resource}
    end
  end

  describe "has_permission?/2" do
    test "returns true when role has permission" do
      assert Authorization.has_permission?(:admin, :org_edit)
    end

    test "returns false when role doesn't have permission" do
      refute Authorization.has_permission?(:member, :org_delete)
    end

    test "returns false for invalid permission" do
      refute Authorization.has_permission?(:admin, :invalid_permission)
    end
  end
end
