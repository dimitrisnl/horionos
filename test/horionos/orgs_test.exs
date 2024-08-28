defmodule Horionos.OrgsTest do
  use Horionos.DataCase

  alias Horionos.Orgs
  alias Horionos.Orgs.{Invitation, Membership, Org}
  alias Horionos.Repo

  import Horionos.AccountsFixtures
  import Horionos.OrgsFixtures

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

  describe "get_org/1" do
    test "returns the org" do
      owner = user_fixture()
      user = user_fixture()
      org = org_fixture(%{user: owner})
      membership_fixture(%{user_id: user.id, org_id: org.id, role: :member})

      assert {:ok, ^org} = Orgs.get_org(org.id)
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

  describe "update_org/2" do
    setup do
      owner = user_fixture()
      org = org_fixture(%{user: owner})
      %{owner: owner, org: org}
    end

    test "updates the org when user has permissions", %{org: org} do
      update_attrs = %{title: "Updated Org"}
      assert {:ok, %Org{} = updated_org} = Orgs.update_org(org, update_attrs)
      assert updated_org.title == "Updated Org"
    end

    test "returns an error changeset with invalid data", %{org: org} do
      assert {:error, %Ecto.Changeset{}} = Orgs.update_org(org, %{title: nil})
    end
  end

  describe "delete_org/1" do
    setup do
      owner = user_fixture()
      org = org_fixture(%{user: owner})
      %{owner: owner, org: org}
    end

    test "deletes the org", %{org: org} do
      assert {:ok, %Org{}} = Orgs.delete_org(org)
      assert {:error, :not_found} = Orgs.get_org(org.id)
    end
  end

  describe "list_org_memberships/1" do
    setup do
      owner = user_fixture()
      member = user_fixture()
      org = org_fixture(%{user: owner})
      membership_fixture(%{user_id: member.id, org_id: org.id, role: :member})
      %{owner: owner, member: member, org: org}
    end

    test "returns memberships", %{org: org} do
      assert {:ok, memberships} = Orgs.list_org_memberships(org)
      # owner and member
      assert length(memberships) == 2
    end
  end

  describe "create_membership/1" do
    setup do
      owner = user_fixture()
      admin = user_fixture()
      member = user_fixture()
      org = org_fixture(%{user: owner})
      membership_fixture(%{user_id: admin.id, org_id: org.id, role: :admin})
      membership_fixture(%{user_id: member.id, org_id: org.id, role: :member})
      %{admin: admin, member: member, org: org}
    end

    test "creates a membership", %{org: org} do
      new_user = user_fixture()
      attrs = %{user_id: new_user.id, org_id: org.id, role: :member}

      assert {:ok, %Membership{} = membership} = Orgs.create_membership(attrs)
      assert membership.user_id == new_user.id
      assert membership.org_id == org.id
      assert membership.role == :member
    end
  end

  describe "update_membership/2" do
    setup do
      owner = user_fixture()
      admin = user_fixture()
      member = user_fixture()
      user = user_fixture()

      org = org_fixture(%{user: owner})

      membership_fixture(%{user_id: admin.id, org_id: org.id, role: :admin})
      membership_fixture(%{user_id: member.id, org_id: org.id, role: :member})
      membership = membership_fixture(%{user_id: user.id, org_id: org.id, role: :member})

      %{member: member, admin: admin, user: user, org: org, membership: membership}
    end

    test "updates the membership when user has permissions", %{
      membership: membership
    } do
      update_attrs = %{role: :admin}

      assert {:ok, %Membership{} = updated_membership} =
               Orgs.update_membership(membership, update_attrs)

      assert updated_membership.role == :admin
    end
  end

  describe "delete_membership/1" do
    setup do
      owner = user_fixture()
      admin = user_fixture()
      member = user_fixture()
      user = user_fixture()

      org = org_fixture(%{user: owner})

      membership_fixture(%{user_id: admin.id, org_id: org.id, role: :admin})
      membership_fixture(%{user_id: member.id, org_id: org.id, role: :member})
      membership = membership_fixture(%{user_id: user.id, org_id: org.id, role: :member})

      %{member: member, admin: admin, user: user, org: org, membership: membership}
    end

    test "deletes the membership when user has permissions", %{
      membership: membership
    } do
      assert {:ok, %Membership{}} = Orgs.delete_membership(membership)
      assert is_nil(Repo.get(Membership, membership.id))
    end
  end

  describe "get_user_role/2" do
    setup do
      owner = user_fixture()
      member = user_fixture()
      org = org_fixture(%{user: owner})
      membership_fixture(%{user_id: member.id, org_id: org.id, role: :member})
      %{owner: owner, member: member, org: org}
    end

    test "returns the correct role for a user", %{owner: owner, member: member, org: org} do
      assert {:ok, :owner} = Orgs.get_user_role(owner, org)
      assert {:ok, :member} = Orgs.get_user_role(member, org)
    end

    test "returns error for a user not in the org", %{org: org} do
      non_member = user_fixture()
      assert {:error, :not_found} = Orgs.get_user_role(non_member, org)
    end
  end

  describe "create_invitation/4" do
    setup do
      owner = user_fixture()
      org = org_fixture(%{user: owner})
      %{owner: owner, org: org}
    end

    test "creates an invitation when user has permissions", %{owner: owner, org: org} do
      email = "test@example.com"

      assert {:ok, %Invitation{} = invitation} =
               Orgs.create_invitation(owner, org, email, :member)

      assert invitation.email == email
      assert invitation.role == :member
    end

    test "returns an error when inviting an existing member", %{owner: owner, org: org} do
      existing_member = user_fixture()
      membership_fixture(%{user_id: existing_member.id, org_id: org.id, role: :member})

      assert {:error, :already_member} =
               Orgs.create_invitation(owner, org, existing_member.email, :member)
    end
  end

  describe "list_org_invitations/1" do
    setup do
      owner = user_fixture()
      org = org_fixture(%{user: owner})
      invitation = invitation_fixture(owner, org, "test@example.com")
      %{owner: owner, org: org, invitation: invitation}
    end

    test "returns invitations", %{
      org: org,
      invitation: invitation
    } do
      assert {:ok, invitations} = Orgs.list_org_invitations(org)
      assert length(invitations) == 1
      assert hd(invitations).id == invitation.id
    end
  end

  describe "accept_invitation/2" do
    setup do
      owner = user_fixture()
      org = org_fixture(%{user: owner})
      invitation = invitation_fixture(owner, org, "test@example.com")
      %{invitation: invitation}
    end

    test "accepts the invitation and creates a membership", %{invitation: invitation} do
      user_params = %{full_name: "Test User", password: valid_user_password()}

      assert {:ok, %{user: user, invitation: accepted_invitation, membership: membership}} =
               Orgs.accept_invitation(invitation, user_params)

      assert user.email == invitation.email
      assert accepted_invitation.accepted_at
      assert membership.user_id == user.id
      assert membership.org_id == invitation.org_id
      assert membership.role == invitation.role
    end

    test "returns an error when invitation is already accepted", %{invitation: invitation} do
      {:ok, %{invitation: updated_invitation}} =
        Orgs.accept_invitation(invitation, %{
          full_name: "Test User",
          password: valid_user_password()
        })

      assert {:error, :already_accepted} =
               Orgs.accept_invitation(updated_invitation, %{
                 full_name: "Another User",
                 password: valid_user_password()
               })
    end
  end

  describe "get_pending_invitation_by_token/1" do
    setup do
      owner = user_fixture()
      org = org_fixture(%{user: owner})
      invitation = invitation_fixture(owner, org, "test@example.com")
      %{invitation: invitation}
    end

    test "returns the invitation when token is valid", %{invitation: invitation} do
      assert %Invitation{} =
               found_invitation = Orgs.get_pending_invitation_by_token(invitation.token)

      assert found_invitation.id == invitation.id
    end

    test "returns nil when token is invalid" do
      assert is_nil(Orgs.get_pending_invitation_by_token("invalid_token"))
    end

    test "returns nil when invitation is already accepted", %{invitation: invitation} do
      Orgs.accept_invitation(invitation, %{
        full_name: "Test User",
        password: valid_user_password()
      })

      assert is_nil(Orgs.get_pending_invitation_by_token(invitation.token))
    end
  end

  describe "delete_invitation/2" do
    setup do
      owner = user_fixture()
      org = org_fixture(%{user: owner})
      invitation = invitation_fixture(owner, org, "test@example.com")
      %{owner: owner, org: org, invitation: invitation}
    end

    test "deletes the invitation", %{
      invitation: invitation
    } do
      assert {:ok, %Invitation{}} = Orgs.delete_invitation(invitation.id)
      assert is_nil(Repo.get(Invitation, invitation.id))
    end

    test "returns an error when invitation doesn't exist" do
      assert {:error, :not_found} = Orgs.delete_invitation(-1)
    end
  end

  describe "send_invitation_email/2" do
    setup do
      owner = user_fixture()
      org = org_fixture(%{user: owner})
      invitation = invitation_fixture(owner, org, "test@example.com")
      %{invitation: invitation}
    end

    test "sends the invitation email", %{invitation: invitation} do
      url_fn = fn token -> "http://example.com/invitations/#{token}" end
      assert {:ok, %Invitation{}} = Orgs.send_invitation_email(invitation, url_fn)
    end
  end

  describe "build_invitation_changeset/2" do
    setup do
      owner = user_fixture()
      org = org_fixture(%{user: owner})
      invitation = invitation_fixture(owner, org, "test@example.com")
      %{invitation: invitation}
    end

    test "returns a valid changeset with valid attributes", %{invitation: invitation} do
      attrs = %{email: "newemail@example.com"}
      changeset = Orgs.build_invitation_changeset(invitation, attrs)
      assert changeset.valid?
    end

    test "returns an invalid changeset with invalid attributes", %{invitation: invitation} do
      attrs = %{email: "invalid_email"}
      changeset = Orgs.build_invitation_changeset(invitation, attrs)
      refute changeset.valid?
    end
  end

  describe "user_in_org?/2" do
    setup do
      owner = user_fixture()
      org = org_fixture(%{user: owner})
      %{owner: owner, org: org}
    end

    test "returns true when user is in org", %{owner: owner, org: org} do
      assert Orgs.user_in_org?(org, owner.email)
    end

    test "returns false when user is not in org", %{org: org} do
      non_member = user_fixture()
      refute Orgs.user_in_org?(org, non_member.email)
    end
  end

  describe "user_has_any_membership?/1" do
    test "returns true when user has memberships" do
      owner = user_fixture()
      org_fixture(%{user: owner})
      assert Orgs.user_has_any_membership?(owner.email)
    end

    test "returns false when user has no memberships" do
      user = user_fixture()
      refute Orgs.user_has_any_membership?(user.email)
    end
  end

  describe "get_user_primary_org/1" do
    test "returns the first org a user joined" do
      owner = user_fixture()
      org1 = org_fixture(%{user: owner})
      org2 = org_fixture(%{user: owner})

      assert Orgs.get_user_primary_org(owner).id == org1.id
      refute Orgs.get_user_primary_org(owner).id == org2.id
    end

    test "returns nil when user has no orgs" do
      user = user_fixture()
      assert Orgs.get_user_primary_org(user) == nil
    end
  end

  describe "build_org_changeset/2" do
    test "returns a valid org changeset" do
      org = org_fixture()
      attrs = %{title: "New Org Title"}
      changeset = Orgs.build_org_changeset(org, attrs)
      assert changeset.valid?
      assert get_change(changeset, :title) == "New Org Title"
    end

    test "returns an invalid org changeset with invalid data" do
      org = org_fixture()
      attrs = %{title: nil}
      changeset = Orgs.build_org_changeset(org, attrs)
      refute changeset.valid?
    end
  end

  describe "edge cases" do
    setup do
      owner = user_fixture()
      admin = user_fixture()
      member = user_fixture()
      org = org_fixture(%{user: owner})
      membership_fixture(%{user_id: admin.id, org_id: org.id, role: :admin})
      membership_fixture(%{user_id: member.id, org_id: org.id, role: :member})
      %{owner: owner, admin: admin, member: member, org: org}
    end

    test "invitation can only be accepted once", %{owner: owner, org: org} do
      {:ok, invitation} = Orgs.create_invitation(owner, org, "test@example.com", :member)

      # Accept invitation
      user_params = %{full_name: "Test User", password: valid_user_password()}

      assert {:ok, %{invitation: updated_invitation}} =
               Orgs.accept_invitation(invitation, user_params)

      # Try to accept again (should fail)
      assert {:error, :already_accepted} = Orgs.accept_invitation(updated_invitation, user_params)
    end

    test "deleting an org cascades to memberships and invitations", %{owner: owner, org: org} do
      # Create some memberships and invitations
      user1 = user_fixture()
      user2 = user_fixture()

      {:ok, _} =
        Orgs.create_membership(%{user_id: user1.id, org_id: org.id, role: :member})

      {:ok, _} =
        Orgs.create_membership(%{user_id: user2.id, org_id: org.id, role: :member})

      {:ok, _} = Orgs.create_invitation(owner, org, "test1@example.com", :member)
      {:ok, _} = Orgs.create_invitation(owner, org, "test2@example.com", :member)

      # Delete org
      assert {:ok, _} = Orgs.delete_org(org)

      # Check that memberships are deleted
      assert Repo.all(Membership) == []

      # Check that invitations are deleted
      assert Repo.all(Invitation) == []
    end

    test "user_has_any_membership? returns correct result after all memberships are deleted", %{
      owner: owner,
      org: org
    } do
      assert Orgs.user_has_any_membership?(owner.email)

      # Delete the org (which cascades to delete all memberships)
      assert {:ok, _} = Orgs.delete_org(org)

      # Check that user no longer has any memberships
      refute Orgs.user_has_any_membership?(owner.email)
    end
  end
end
