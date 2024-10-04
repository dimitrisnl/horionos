defmodule Horionos.AuthorizationTest do
  use Horionos.DataCase, async: true

  import Horionos.AccountsFixtures
  import Horionos.OrganizationsFixtures

  alias Horionos.Authorization

  describe "authorize/3" do
    setup do
      owner = user_fixture()
      admin = user_fixture()
      member = user_fixture()
      non_member = user_fixture()

      organization = organization_fixture(%{user: owner})

      membership_fixture(%{user_id: admin.id, organization_id: organization.id, role: :admin})
      membership_fixture(%{user_id: member.id, organization_id: organization.id, role: :member})

      %{
        owner: owner,
        admin: admin,
        member: member,
        non_member: non_member,
        organization: organization
      }
    end

    test "allows owner to perform owner actions", %{owner: owner, organization: organization} do
      assert :ok == Authorization.authorize(owner, organization, :organization_delete)
    end

    test "allows owner to perform admin actions", %{owner: owner, organization: organization} do
      assert :ok == Authorization.authorize(owner, organization, :organization_edit)
    end

    test "allows owner to perform member actions", %{owner: owner, organization: organization} do
      assert :ok == Authorization.authorize(owner, organization, :organization_view)
    end

    test "allows admin to perform admin actions", %{admin: admin, organization: organization} do
      assert :ok == Authorization.authorize(admin, organization, :organization_edit)
    end

    test "allows admin to perform member actions", %{admin: admin, organization: organization} do
      assert :ok == Authorization.authorize(admin, organization, :organization_view)
    end

    test "denies admin from performing owner actions", %{admin: admin, organization: organization} do
      assert {:error, :unauthorized} ==
               Authorization.authorize(admin, organization, :organization_delete)
    end

    test "allows member to perform member actions", %{member: member, organization: organization} do
      assert :ok == Authorization.authorize(member, organization, :organization_view)
    end

    test "denies member from performing admin actions", %{
      member: member,
      organization: organization
    } do
      assert {:error, :unauthorized} ==
               Authorization.authorize(member, organization, :organization_edit)
    end

    test "denies non-member from performing any action", %{
      non_member: non_member,
      organization: organization
    } do
      assert {:error, :unauthorized} ==
               Authorization.authorize(non_member, organization, :organization_view)
    end

    test "handles invalid permissions", %{owner: owner, organization: organization} do
      assert {:error, :unauthorized} ==
               Authorization.authorize(owner, organization, :invalid_permission)
    end
  end

  describe "get_organization_from_resource/1" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})
      %{organization: organization}
    end

    test "returns organization when given an Organization struct", %{organization: organization} do
      assert Authorization.get_organization_from_resource(organization) == {:ok, organization}
    end

    test "returns organization when given a struct with organization_id", %{
      organization: organization
    } do
      resource = %{organization_id: organization.id}
      assert Authorization.get_organization_from_resource(resource) == {:ok, organization}
    end

    test "returns error for invalid resource" do
      assert Authorization.get_organization_from_resource(%{}) == {:error, :invalid_resource}
    end
  end

  describe "has_permission?/2" do
    test "returns true when role has permission" do
      assert Authorization.has_permission?(:admin, :organization_edit)
    end

    test "returns false when role doesn't have permission" do
      refute Authorization.has_permission?(:member, :organization_delete)
    end

    test "returns false for invalid permission" do
      refute Authorization.has_permission?(:admin, :invalid_permission)
    end
  end
end
