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

  describe "get_org/2" do
    test "returns the org for a user with access" do
      owner = user_fixture()
      user = user_fixture()
      org = org_fixture(%{user: owner})
      membership_fixture(owner, %{user_id: user.id, org_id: org.id, role: :member})

      assert {:ok, ^org} = Orgs.get_org(user, org.id)
    end

    test "returns error for a user without access" do
      user = user_fixture()
      org = org_fixture()

      assert {:error, :unauthorized} = Orgs.get_org(user, org.id)
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
      assert {:error, :unauthorized} = Orgs.get_org(owner, org.id)
    end

    test "returns an error when user is not owner", %{org: org, owner: owner} do
      non_owner = user_fixture()
      membership_fixture(owner, %{user_id: non_owner.id, org_id: org.id, role: :admin})
      assert {:error, :unauthorized} = Orgs.delete_org(non_owner, org)
    end
  end

  describe "list_org_memberships/2" do
    setup do
      owner = user_fixture()
      member = user_fixture()
      org = org_fixture(%{user: owner})
      membership_fixture(owner, %{user_id: member.id, org_id: org.id, role: :member})
      %{owner: owner, member: member, org: org}
    end

    test "returns memberships when user has permissions", %{owner: owner, org: org} do
      assert {:ok, memberships} = Orgs.list_org_memberships(owner, org)
      # owner and member
      assert length(memberships) == 2
    end

    test "returns error when user doesn't have permissions", %{org: org} do
      non_member = user_fixture()
      assert {:error, :unauthorized} = Orgs.list_org_memberships(non_member, org)
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
      membership = membership_fixture(owner, %{user_id: user.id, org_id: org.id, role: :member})

      %{member: member, admin: admin, user: user, org: org, membership: membership}
    end

    test "updates the membership when user has permissions", %{
      admin: admin,
      membership: membership
    } do
      update_attrs = %{role: :admin}

      assert {:ok, %Membership{} = updated_membership} =
               Orgs.update_membership(admin, membership, update_attrs)

      assert updated_membership.role == :admin
    end

    test "returns an error when user doesn't have permissions as member", %{
      member: member,
      membership: membership
    } do
      update_attrs = %{role: :admin}

      assert {:error, :unauthorized} = Orgs.update_membership(member, membership, update_attrs)
    end

    test "returns an error when user doesn't have permissions", %{membership: membership} do
      non_admin = user_fixture()
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
      membership = membership_fixture(owner, %{user_id: user.id, org_id: org.id, role: :member})

      %{member: member, admin: admin, user: user, org: org, membership: membership}
    end

    test "deletes the membership when user has permissions", %{
      admin: admin,
      membership: membership
    } do
      assert {:ok, %Membership{}} = Orgs.delete_membership(admin, membership)
      assert is_nil(Repo.get(Membership, membership.id))
    end

    test "returns an error when user doesn't have permissions as member", %{
      member: member,
      membership: membership
    } do
      assert {:error, :unauthorized} = Orgs.delete_membership(member, membership)
    end

    test "returns an error when user doesn't have permissions", %{membership: membership} do
      non_admin = user_fixture()
      assert {:error, :unauthorized} = Orgs.delete_membership(non_admin, membership)
    end
  end

  describe "get_user_role/2" do
    setup do
      owner = user_fixture()
      member = user_fixture()
      org = org_fixture(%{user: owner})
      membership_fixture(owner, %{user_id: member.id, org_id: org.id, role: :member})
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

    test "returns an error when user doesn't have permissions", %{org: org} do
      non_member = user_fixture()

      assert {:error, :unauthorized} =
               Orgs.create_invitation(non_member, org, "test@example.com", :member)
    end

    test "returns an error when inviting an existing member", %{owner: owner, org: org} do
      existing_member = user_fixture()
      membership_fixture(owner, %{user_id: existing_member.id, org_id: org.id, role: :member})

      assert {:error, :already_member} =
               Orgs.create_invitation(owner, org, existing_member.email, :member)
    end
  end

  describe "list_org_invitations/2" do
    setup do
      owner = user_fixture()
      org = org_fixture(%{user: owner})
      invitation = invitation_fixture(owner, org, "test@example.com")
      %{owner: owner, org: org, invitation: invitation}
    end

    test "returns invitations when user has permissions", %{
      owner: owner,
      org: org,
      invitation: invitation
    } do
      assert {:ok, invitations} = Orgs.list_org_invitations(owner, org)
      assert length(invitations) == 1
      assert hd(invitations).id == invitation.id
    end

    test "returns error when user doesn't have permissions", %{org: org} do
      non_member = user_fixture()
      assert {:error, :unauthorized} = Orgs.list_org_invitations(non_member, org)
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

  describe "cancel_invitation/3" do
    setup do
      owner = user_fixture()
      org = org_fixture(%{user: owner})
      invitation = invitation_fixture(owner, org, "test@example.com")
      %{owner: owner, org: org, invitation: invitation}
    end

    test "cancels the invitation when user has permissions", %{
      owner: owner,
      org: org,
      invitation: invitation
    } do
      assert {:ok, %Invitation{}} = Orgs.cancel_invitation(owner, org, invitation.id)
      assert is_nil(Repo.get(Invitation, invitation.id))
    end

    test "returns an error when user doesn't have permissions", %{
      org: org,
      invitation: invitation
    } do
      non_admin = user_fixture()
      assert {:error, :unauthorized} = Orgs.cancel_invitation(non_admin, org, invitation.id)
    end

    test "returns an error when invitation doesn't exist", %{owner: owner, org: org} do
      assert {:error, :not_found} = Orgs.cancel_invitation(owner, org, -1)
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
      # You might want to add more assertions here to check if the email was actually sent
      # This could involve checking a test mailbox or mocking the email sending function
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

  describe "edge cases and integration scenarios" do
    setup do
      owner = user_fixture()
      admin = user_fixture()
      member = user_fixture()
      org = org_fixture(%{user: owner})
      membership_fixture(owner, %{user_id: admin.id, org_id: org.id, role: :admin})
      membership_fixture(owner, %{user_id: member.id, org_id: org.id, role: :member})
      %{owner: owner, admin: admin, member: member, org: org}
    end

    test "owner can perform all actions", %{owner: owner, org: org} do
      new_user = user_fixture()

      # Create invitation
      assert {:ok, invitation} = Orgs.create_invitation(owner, org, "test@example.com", :member)

      # List invitations
      assert {:ok, all_invitations} = Orgs.list_org_invitations(owner, org)
      assert length(all_invitations) == 1
      assert hd(all_invitations).id == invitation.id

      # Cancel invitation
      assert {:ok, _} = Orgs.cancel_invitation(owner, org, invitation.id)

      # Create membership
      assert {:ok, membership} =
               Orgs.create_membership(owner, %{
                 user_id: new_user.id,
                 org_id: org.id,
                 role: :member
               })

      # Update membership
      assert {:ok, updated_membership} =
               Orgs.update_membership(owner, membership, %{role: :admin})

      assert updated_membership.role == :admin

      # Delete membership
      assert {:ok, _} = Orgs.delete_membership(owner, updated_membership)

      # Update org
      assert {:ok, updated_org} = Orgs.update_org(owner, org, %{title: "Updated Org"})
      assert updated_org.title == "Updated Org"

      # Delete org
      assert {:ok, _} = Orgs.delete_org(owner, updated_org)
    end

    test "admin can perform most actions except deleting the org", %{admin: admin, org: org} do
      new_user = user_fixture()

      # Create invitation
      assert {:ok, invitation} = Orgs.create_invitation(admin, org, "test@example.com", :member)

      # List invitations
      assert {:ok, all_invitations} = Orgs.list_org_invitations(admin, org)
      assert length(all_invitations) == 1
      assert hd(all_invitations).id == invitation.id

      # Cancel invitation
      assert {:ok, _} = Orgs.cancel_invitation(admin, org, invitation.id)

      # Create membership
      assert {:ok, membership} =
               Orgs.create_membership(admin, %{
                 user_id: new_user.id,
                 org_id: org.id,
                 role: :member
               })

      # Update membership
      assert {:ok, updated_membership} =
               Orgs.update_membership(admin, membership, %{role: :admin})

      assert updated_membership.role == :admin

      # Delete membership
      assert {:ok, _} = Orgs.delete_membership(admin, updated_membership)

      # Update org
      assert {:ok, updated_org} = Orgs.update_org(admin, org, %{title: "Updated Org"})
      assert updated_org.title == "Updated Org"

      # Try to delete org (should fail)
      assert {:error, :unauthorized} = Orgs.delete_org(admin, updated_org)
    end

    test "member can only view org and list memberships", %{member: member, org: org} do
      # Get org
      assert {:ok, _} = Orgs.get_org(member, org.id)

      # List memberships
      assert {:ok, memberships} = Orgs.list_org_memberships(member, org)
      # owner, admin, member
      assert length(memberships) == 3

      # Try to create invitation (should fail)
      assert {:error, :unauthorized} =
               Orgs.create_invitation(member, org, "test@example.com", :member)

      # Try to create membership (should fail)
      new_user = user_fixture()

      assert {:error, :unauthorized} =
               Orgs.create_membership(member, %{
                 user_id: new_user.id,
                 org_id: org.id,
                 role: :member
               })

      # Try to update org (should fail)
      assert {:error, :unauthorized} = Orgs.update_org(member, org, %{title: "Updated Org"})
    end

    test "user cannot access org after membership is deleted", %{
      owner: owner,
      member: member,
      org: org
    } do
      membership = Repo.get_by(Membership, user_id: member.id, org_id: org.id)

      # Delete membership
      assert {:ok, _} = Orgs.delete_membership(owner, membership)

      # Try to access org (should fail)
      assert {:error, :unauthorized} = Orgs.get_org(member, org.id)
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

    test "user roles are properly enforced", %{
      owner: owner,
      admin: admin,
      member: member,
      org: org
    } do
      new_user = user_fixture()

      # Owner can create admin
      assert {:ok, _admin_membership} =
               Orgs.create_membership(owner, %{
                 user_id: new_user.id,
                 org_id: org.id,
                 role: :admin
               })

      # Admin can create member
      another_user = user_fixture()

      assert {:ok, _member_membership} =
               Orgs.create_membership(admin, %{
                 user_id: another_user.id,
                 org_id: org.id,
                 role: :member
               })

      # Admin cannot create owner
      yet_another_user = user_fixture()

      assert {:error, _} =
               Orgs.create_membership(admin, %{
                 user_id: yet_another_user.id,
                 org_id: org.id,
                 role: :owner
               })

      # Member cannot create any role
      final_user = user_fixture()

      assert {:error, :unauthorized} =
               Orgs.create_membership(member, %{
                 user_id: final_user.id,
                 org_id: org.id,
                 role: :member
               })
    end

    test "deleting an org cascades to memberships and invitations", %{owner: owner, org: org} do
      # Create some memberships and invitations
      user1 = user_fixture()
      user2 = user_fixture()

      {:ok, _} =
        Orgs.create_membership(owner, %{user_id: user1.id, org_id: org.id, role: :member})

      {:ok, _} =
        Orgs.create_membership(owner, %{user_id: user2.id, org_id: org.id, role: :member})

      {:ok, _} = Orgs.create_invitation(owner, org, "test1@example.com", :member)
      {:ok, _} = Orgs.create_invitation(owner, org, "test2@example.com", :member)

      # Delete org
      assert {:ok, _} = Orgs.delete_org(owner, org)

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
      assert {:ok, _} = Orgs.delete_org(owner, org)

      # Check that user no longer has any memberships
      refute Orgs.user_has_any_membership?(owner.email)
    end
  end

  describe "integration scenarios" do
    test "full lifecycle of an org" do
      # Create a user and an org
      owner = user_fixture()
      {:ok, org} = Orgs.create_org(owner, %{title: "New Org"})

      # Invite a new user
      {:ok, invitation} = Orgs.create_invitation(owner, org, "newuser@example.com", :member)

      # Accept the invitation
      {:ok, %{user: new_user}} =
        Orgs.accept_invitation(invitation, %{
          full_name: "New User",
          password: valid_user_password()
        })

      # Owner updates the new user's role to admin
      membership = Repo.get_by(Membership, user_id: new_user.id, org_id: org.id)
      {:ok, _} = Orgs.update_membership(owner, membership, %{role: :admin})

      # New admin invites another user
      {:ok, another_invitation} =
        Orgs.create_invitation(new_user, org, "another@example.com", :member)

      # Owner decides to cancel the invitation
      {:ok, _} = Orgs.cancel_invitation(owner, org, another_invitation.id)

      # Owner updates org details
      {:ok, updated_org} = Orgs.update_org(owner, org, %{title: "Updated Org Title"})
      assert updated_org.title == "Updated Org Title"

      # Owner deletes the org
      {:ok, _} = Orgs.delete_org(owner, updated_org)

      # Verify that the org and all related data are deleted
      assert {:error, :unauthorized} = Orgs.get_org(owner, org.id)
      assert Repo.all(Membership) == []
      assert Repo.all(Invitation) == []
    end
  end
end
