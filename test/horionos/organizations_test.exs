defmodule Horionos.OrganizationsTest do
  use Horionos.DataCase

  alias Horionos.Organizations
  alias Horionos.Organizations.{Invitation, Membership, Organization}
  alias Horionos.Repo

  import Horionos.AccountsFixtures
  import Horionos.OrganizationsFixtures

  describe "list_user_memberships/1" do
    test "returns all memberships for a given user" do
      owner = user_fixture()
      organization1 = organization_fixture(%{user: owner})
      organization2 = organization_fixture(%{user: owner})

      {:ok, memberships} = Organizations.list_user_memberships(owner)
      assert length(memberships) == 2

      assert Enum.all?(memberships, fn membership ->
               membership.organization.id in [organization1.id, organization2.id]
             end)
    end

    test "returns an empty list for a user with no organizations" do
      user = user_fixture()
      assert Organizations.list_user_memberships(user) == {:ok, []}
    end
  end

  describe "get_organization/1" do
    test "returns the organization" do
      owner = user_fixture()
      user = user_fixture()
      organization = organization_fixture(%{user: owner})
      membership_fixture(%{user_id: user.id, organization_id: organization.id, role: :member})

      assert {:ok, ^organization} = Organizations.get_organization(organization.id)
    end
  end

  describe "create_organization/2" do
    test "creates an organization and adds the user as an owner" do
      user = user_fixture()
      attrs = %{title: "Test Organization"}

      assert {:ok, %Organization{} = organization} =
               Organizations.create_organization(user, attrs)

      assert organization.title == "Test Organization"

      membership = Repo.get_by(Membership, user_id: user.id, organization_id: organization.id)
      assert membership.role == :owner
    end

    test "returns an error changeset with invalid data" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Organizations.create_organization(user, %{title: nil})
    end
  end

  describe "update_organization/2" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})
      %{owner: owner, organization: organization}
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
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})
      %{owner: owner, organization: organization}
    end

    test "deletes the organization", %{organization: organization} do
      assert {:ok, %Organization{}} = Organizations.delete_organization(organization)
      assert {:error, :not_found} = Organizations.get_organization(organization.id)
    end
  end

  describe "list_organization_memberships/1" do
    setup do
      owner = user_fixture()
      member = user_fixture()
      organization = organization_fixture(%{user: owner})
      membership_fixture(%{user_id: member.id, organization_id: organization.id, role: :member})
      %{owner: owner, member: member, organization: organization}
    end

    test "returns memberships", %{organization: organization} do
      assert {:ok, memberships} = Organizations.list_organization_memberships(organization)
      # owner and member
      assert length(memberships) == 2
    end
  end

  describe "create_membership/1" do
    setup do
      owner = user_fixture()
      admin = user_fixture()
      member = user_fixture()
      organization = organization_fixture(%{user: owner})
      membership_fixture(%{user_id: admin.id, organization_id: organization.id, role: :admin})
      membership_fixture(%{user_id: member.id, organization_id: organization.id, role: :member})
      %{admin: admin, member: member, organization: organization}
    end

    test "creates a membership", %{organization: organization} do
      new_user = user_fixture()
      attrs = %{user_id: new_user.id, organization_id: organization.id, role: :member}

      assert {:ok, %Membership{} = membership} = Organizations.create_membership(attrs)
      assert membership.user_id == new_user.id
      assert membership.organization_id == organization.id
      assert membership.role == :member
    end
  end

  describe "update_membership/2" do
    setup do
      owner = user_fixture()
      admin = user_fixture()
      member = user_fixture()
      user = user_fixture()

      organization = organization_fixture(%{user: owner})

      membership_fixture(%{user_id: admin.id, organization_id: organization.id, role: :admin})
      membership_fixture(%{user_id: member.id, organization_id: organization.id, role: :member})

      membership =
        membership_fixture(%{user_id: user.id, organization_id: organization.id, role: :member})

      %{
        member: member,
        admin: admin,
        user: user,
        organization: organization,
        membership: membership
      }
    end

    test "updates the membership when user has permissions", %{
      membership: membership
    } do
      update_attrs = %{role: :admin}

      assert {:ok, %Membership{} = updated_membership} =
               Organizations.update_membership(membership, update_attrs)

      assert updated_membership.role == :admin
    end
  end

  describe "delete_membership/1" do
    setup do
      owner = user_fixture()
      member1 = user_fixture()
      member2 = user_fixture()

      organization = organization_fixture(%{user: owner})

      membership_fixture(%{user_id: member1.id, organization_id: organization.id, role: :member})

      membership =
        membership_fixture(%{user_id: member2.id, organization_id: organization.id, role: :member})

      %{
        organization: organization,
        member1: member1,
        member2: member2,
        membership: membership
      }
    end

    test "deletes the membership when user has permissions", %{
      membership: membership,
      member1: member1,
      member2: member2
    } do
      assert {:ok, %Membership{}} = Organizations.delete_membership(membership)

      member1_memberships =
        Membership
        |> where([m], m.user_id == ^member1.id)
        |> Repo.all()

      assert length(member1_memberships) == 1

      member2_memberships =
        Membership
        |> where([m], m.user_id == ^member2.id)
        |> Repo.all()

      assert member2_memberships == []
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
      assert {:ok, :owner} = Organizations.get_user_role(owner, organization)
      assert {:ok, :member} = Organizations.get_user_role(member, organization)
    end

    test "returns error for a user not in the organization", %{organization: organization} do
      non_member = user_fixture()
      assert {:error, :not_found} = Organizations.get_user_role(non_member, organization)
    end
  end

  describe "create_invitation/4" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})
      %{owner: owner, organization: organization}
    end

    test "creates an invitation when user has permissions", %{
      owner: owner,
      organization: organization
    } do
      email = "test@example.com"

      assert {:ok, %{invitation: invitation, token: token}} =
               Organizations.create_invitation(owner, organization, email, :member)

      assert invitation.email == email
      assert invitation.role == :member
      assert is_binary(invitation.token)
      assert is_binary(token)
      assert invitation.expires_at
    end

    test "returns an error when inviting an existing member", %{
      owner: owner,
      organization: organization
    } do
      existing_member = user_fixture()

      membership_fixture(%{
        user_id: existing_member.id,
        organization_id: organization.id,
        role: :member
      })

      assert {:error, :already_member} =
               Organizations.create_invitation(
                 owner,
                 organization,
                 existing_member.email,
                 :member
               )
    end
  end

  describe "list_pending_organization_invitations/1" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})
      %{invitation: invitation1} = invitation_fixture(owner, organization, "test1@example.com")
      %{invitation: invitation2} = invitation_fixture(owner, organization, "test2@example.com")

      {:ok, _updated_invitation} =
        Repo.update(
          Ecto.Changeset.change(invitation2,
            accepted_at: DateTime.utc_now() |> DateTime.truncate(:second)
          )
        )

      %{owner: owner, organization: organization, invitation: invitation1}
    end

    test "returns invitations", %{
      organization: organization,
      invitation: invitation
    } do
      assert {:ok, invitations} =
               Organizations.list_pending_organization_invitations(organization)

      assert length(invitations) == 1
      assert hd(invitations).id == invitation.id
    end
  end

  describe "accept_invitation/2" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})
      %{invitation: invitation} = invitation_fixture(owner, organization, "test@example.com")
      %{invitation: invitation}
    end

    test "accepts the invitation and creates a membership", %{invitation: invitation} do
      user_params = %{full_name: "Test User", password: valid_user_password()}

      assert {:ok, %{user: user, invitation: accepted_invitation, membership: membership}} =
               Organizations.accept_invitation(invitation, user_params)

      assert user.email == invitation.email
      assert accepted_invitation.accepted_at
      assert user.confirmed_at
      assert membership.user_id == user.id
      assert membership.organization_id == invitation.organization_id
      assert membership.role == invitation.role
    end

    test "returns an error when invitation is already accepted", %{invitation: invitation} do
      {:ok, %{invitation: updated_invitation}} =
        Organizations.accept_invitation(invitation, %{
          full_name: "Test User",
          password: valid_user_password()
        })

      assert {:error, :already_accepted} =
               Organizations.accept_invitation(updated_invitation, %{
                 full_name: "Another User",
                 password: valid_user_password()
               })
    end

    test "returns an error when invitation has expired", %{invitation: invitation} do
      expired_at = DateTime.utc_now() |> DateTime.add(-8, :day) |> DateTime.truncate(:second)

      {:ok, expired_invitation} =
        Repo.update(Ecto.Changeset.change(invitation, expires_at: expired_at))

      assert {:error, :expired} =
               Organizations.accept_invitation(expired_invitation, %{
                 full_name: "Test User",
                 password: valid_user_password()
               })
    end
  end

  describe "get_pending_invitation_by_token/1" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})

      %{invitation: invitation, token: token} =
        invitation_fixture(owner, organization, "test@example.com")

      %{invitation: invitation, token: token}
    end

    test "returns the invitation when token is valid", %{invitation: invitation, token: token} do
      assert {:ok, found_invitation} = Organizations.get_pending_invitation_by_token(token)
      assert found_invitation.id == invitation.id
    end

    test "returns error when token is invalid" do
      assert {:error, :invalid_token} =
               Organizations.get_pending_invitation_by_token("invalid_token")
    end

    test "returns error when invitation is already accepted", %{
      invitation: invitation,
      token: token
    } do
      Organizations.accept_invitation(invitation, %{
        full_name: "Test User",
        password: valid_user_password()
      })

      assert {:error, :invalid_token} = Organizations.get_pending_invitation_by_token(token)
    end

    test "returns error when invitation has expired", %{invitation: invitation, token: token} do
      expired_at = DateTime.utc_now() |> DateTime.add(-8, :day) |> DateTime.truncate(:second)
      Repo.update!(Ecto.Changeset.change(invitation, expires_at: expired_at))

      assert {:error, :invalid_token} = Organizations.get_pending_invitation_by_token(token)
    end
  end

  describe "delete_invitation/1" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})
      %{invitation: invitation} = invitation_fixture(owner, organization, "test@example.com")
      %{owner: owner, organization: organization, invitation: invitation}
    end

    test "deletes the invitation", %{
      invitation: invitation
    } do
      assert {:ok, %Invitation{}} = Organizations.delete_invitation(invitation.id)
      assert is_nil(Repo.get(Invitation, invitation.id))
    end

    test "returns an error when invitation doesn't exist" do
      assert {:error, :not_found} = Organizations.delete_invitation(-1)
    end
  end

  describe "send_invitation_email/2" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})

      %{invitation: invitation, token: token} =
        invitation_fixture(owner, organization, "test@example.com")

      %{invitation: invitation, token: token}
    end

    test "sends the invitation email", %{invitation: invitation, token: token} do
      url = "http://example.com/invitations/#{token}"
      assert {:ok, %Invitation{}} = Organizations.send_invitation_email(invitation, url)
    end
  end

  describe "delete_expired_invitations/0" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})

      # Create an expired invitation
      %{invitation: expired_invitation} =
        invitation_fixture(owner, organization, "expired@example.com")

      expired_at = DateTime.utc_now() |> DateTime.add(-8, :day) |> DateTime.truncate(:second)
      Repo.update!(Ecto.Changeset.change(expired_invitation, expires_at: expired_at))

      # Create a valid invitation
      %{invitation: valid_invitation} =
        invitation_fixture(owner, organization, "valid@example.com")

      # Create an accepted invitation
      %{invitation: accepted_invitation} =
        invitation_fixture(owner, organization, "accepted@example.com")

      Repo.update!(
        Ecto.Changeset.change(accepted_invitation,
          accepted_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )
      )

      %{
        expired_invitation: expired_invitation,
        valid_invitation: valid_invitation,
        accepted_invitation: accepted_invitation
      }
    end

    test "deletes only expired and unaccepted invitations", %{
      expired_invitation: expired_invitation,
      valid_invitation: valid_invitation,
      accepted_invitation: accepted_invitation
    } do
      assert {1, nil} = Organizations.delete_expired_invitations()

      assert is_nil(Repo.get(Invitation, expired_invitation.id))
      assert Repo.get(Invitation, valid_invitation.id)
      assert Repo.get(Invitation, accepted_invitation.id)
    end

    test "returns 0 when no expired invitations exist" do
      # First, delete the expired invitation
      Organizations.delete_expired_invitations()

      # Now, there should be no expired invitations left
      assert {0, nil} = Organizations.delete_expired_invitations()
    end

    test "doesn't delete accepted invitations even if they're expired", %{
      accepted_invitation: accepted_invitation
    } do
      # Make the accepted invitation expired
      expired_at = DateTime.utc_now() |> DateTime.add(-8, :day) |> DateTime.truncate(:second)
      Repo.update!(Ecto.Changeset.change(accepted_invitation, expires_at: expired_at))

      Organizations.delete_expired_invitations()

      assert Repo.get(Invitation, accepted_invitation.id)
    end
  end

  describe "build_invitation_changeset/2" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})
      %{invitation: invitation} = invitation_fixture(owner, organization, "test@example.com")
      %{invitation: invitation}
    end

    test "returns a valid changeset with valid attributes", %{invitation: invitation} do
      attrs = %{email: "newemail@example.com"}
      changeset = Organizations.build_invitation_changeset(invitation, attrs)
      assert changeset.valid?
    end

    test "returns an invalid changeset with invalid attributes", %{invitation: invitation} do
      attrs = %{email: "invalid_email"}
      changeset = Organizations.build_invitation_changeset(invitation, attrs)
      refute changeset.valid?
    end
  end

  describe "user_in_organization?/2" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})
      %{owner: owner, organization: organization}
    end

    test "returns true when user is in organization", %{owner: owner, organization: organization} do
      assert Organizations.user_in_organization?(organization, owner.email)
    end

    test "returns false when user is not in organization", %{organization: organization} do
      non_member = user_fixture()
      refute Organizations.user_in_organization?(organization, non_member.email)
    end
  end

  describe "user_has_any_membership?/1" do
    test "returns true when user has memberships" do
      owner = user_fixture()
      organization_fixture(%{user: owner})
      assert Organizations.user_has_any_membership?(owner.email)
    end

    test "returns false when user has no memberships" do
      user = user_fixture()
      refute Organizations.user_has_any_membership?(user.email)
    end
  end

  describe "get_user_primary_organization/1" do
    test "returns the first organization a user joined" do
      owner = user_fixture()
      organization1 = organization_fixture(%{user: owner})
      organization2 = organization_fixture(%{user: owner})

      assert Organizations.get_user_primary_organization(owner).id == organization1.id
      refute Organizations.get_user_primary_organization(owner).id == organization2.id
    end

    test "returns nil when user has no organizations" do
      user = user_fixture()
      assert Organizations.get_user_primary_organization(user) == nil
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
    setup do
      owner = user_fixture()
      admin = user_fixture()
      member = user_fixture()
      organization = organization_fixture(%{user: owner})
      membership_fixture(%{user_id: admin.id, organization_id: organization.id, role: :admin})
      membership_fixture(%{user_id: member.id, organization_id: organization.id, role: :member})
      %{owner: owner, admin: admin, member: member, organization: organization}
    end

    test "invitation can only be accepted once", %{owner: owner, organization: organization} do
      %{invitation: invitation} = invitation_fixture(owner, organization, "test@example.com")

      # Accept invitation
      user_params = %{full_name: "Test User", password: valid_user_password()}

      assert {:ok, %{invitation: updated_invitation}} =
               Organizations.accept_invitation(invitation, user_params)

      # Try to accept again (should fail)
      assert {:error, :already_accepted} =
               Organizations.accept_invitation(updated_invitation, user_params)
    end

    test "deleting an organization cascades to memberships and invitations", %{
      owner: owner,
      organization: organization
    } do
      # Create some memberships and invitations
      user1 = user_fixture()
      user2 = user_fixture()

      {:ok, _} =
        Organizations.create_membership(%{
          user_id: user1.id,
          organization_id: organization.id,
          role: :member
        })

      {:ok, _} =
        Organizations.create_membership(%{
          user_id: user2.id,
          organization_id: organization.id,
          role: :member
        })

      {:ok, _} =
        Organizations.create_invitation(owner, organization, "test1@example.com", :member)

      {:ok, _} =
        Organizations.create_invitation(owner, organization, "test2@example.com", :member)

      # Delete organization
      assert {:ok, _} = Organizations.delete_organization(organization)

      # Check that memberships are deleted
      assert Repo.all(Membership) == []

      # Check that invitations are deleted
      assert Repo.all(Invitation) == []
    end

    test "user_has_any_membership? returns correct result after all memberships are deleted", %{
      owner: owner,
      organization: organization
    } do
      assert Organizations.user_has_any_membership?(owner.email)

      # Delete the organization (which cascades to delete all memberships)
      assert {:ok, _} = Organizations.delete_organization(organization)

      # Check that user no longer has any memberships
      refute Organizations.user_has_any_membership?(owner.email)
    end
  end
end
