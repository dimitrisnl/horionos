defmodule Horionos.InvitationsTest do
  use Horionos.DataCase, async: true

  import Horionos.AccountsFixtures
  import Horionos.OrganizationsFixtures
  import Horionos.MembershipsFixtures
  import Horionos.InvitationsFixtures

  alias Horionos.Invitations.Invitations
  alias Horionos.Invitations.Schemas.Invitation
  alias Horionos.Repo

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
               Invitations.create_invitation(owner, organization, email, :member)

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
               Invitations.create_invitation(
                 owner,
                 organization,
                 existing_member.email,
                 :member
               )
    end

    test "returns an error when user doesn't have permission", %{
      organization: organization
    } do
      non_member = user_fixture()

      assert {:error, :unauthorized} =
               Invitations.create_invitation(
                 non_member,
                 organization,
                 "test@example.com",
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
            accepted_at: DateTime.utc_now(:second)
          )
        )

      %{organization: organization, invitation: invitation1}
    end

    test "returns invitations", %{
      organization: organization,
      invitation: invitation
    } do
      assert {:ok, [returned_invitation]} =
               Invitations.list_pending_organization_invitations(organization)

      assert returned_invitation.id == invitation.id
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
               Invitations.accept_invitation(invitation, user_params)

      assert user.email == invitation.email
      assert accepted_invitation.accepted_at
      assert user.confirmed_at
      assert membership.user_id == user.id
      assert membership.organization_id == invitation.organization_id
      assert membership.role == invitation.role
    end

    test "returns an error when invitation is already accepted", %{invitation: invitation} do
      {:ok, %{invitation: updated_invitation}} =
        Invitations.accept_invitation(invitation, %{
          full_name: "Test User",
          password: valid_user_password()
        })

      assert {:error, :already_accepted} =
               Invitations.accept_invitation(updated_invitation, %{
                 full_name: "Another User",
                 password: valid_user_password()
               })
    end

    test "returns an error when invitation has expired", %{invitation: invitation} do
      expired_at =
        DateTime.utc_now()
        |> DateTime.add(-8, :day)
        |> DateTime.truncate(:second)

      {:ok, expired_invitation} =
        Repo.update(Ecto.Changeset.change(invitation, expires_at: expired_at))

      assert {:error, :expired} =
               Invitations.accept_invitation(expired_invitation, %{
                 full_name: "Test User",
                 password: valid_user_password()
               })
    end

    test "returns an error with invalid user params", %{invitation: invitation} do
      invalid_user_params = %{full_name: "", password: "short"}

      assert {
               :error,
               :user,
               {:user_creation_failed,
                %{password: ["should be at least 12 character(s)"], full_name: ["can't be blank"]}},
               %{}
             } =
               Invitations.accept_invitation(invitation, invalid_user_params)
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
      assert {:ok, found_invitation} = Invitations.get_pending_invitation_by_token(token)
      assert found_invitation.id == invitation.id
    end

    test "returns error when token is invalid" do
      assert {:error, :invalid_token} =
               Invitations.get_pending_invitation_by_token("invalid_token")
    end

    test "returns error when invitation is already accepted", %{
      invitation: invitation,
      token: token
    } do
      Invitations.accept_invitation(invitation, %{
        full_name: "Test User",
        password: valid_user_password()
      })

      assert {:error, :invalid_token} = Invitations.get_pending_invitation_by_token(token)
    end

    test "returns error when invitation has expired", %{invitation: invitation, token: token} do
      expired_at =
        DateTime.utc_now()
        |> DateTime.add(-8, :day)
        |> DateTime.truncate(:second)

      {:ok, _} = Repo.update(Ecto.Changeset.change(invitation, expires_at: expired_at))
      assert {:error, :invalid_token} = Invitations.get_pending_invitation_by_token(token)
    end
  end

  describe "delete_invitation/1" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})
      %{invitation: invitation} = invitation_fixture(owner, organization, "test@example.com")
      %{invitation: invitation}
    end

    test "deletes the invitation", %{invitation: invitation} do
      assert {:ok, %Invitation{}} = Invitations.delete_invitation(invitation.id)
      assert is_nil(Repo.get(Invitation, invitation.id))
    end

    test "returns an error when invitation doesn't exist" do
      assert {:error, :not_found} = Invitations.delete_invitation(-1)
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
      assert {:ok, %Invitation{}} = Invitations.send_invitation_email(invitation, url)
    end
  end

  describe "delete_expired_invitations/0" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})

      # Create an expired invitation
      %{invitation: expired_invitation} =
        invitation_fixture(owner, organization, "expired@example.com")

      expired_at =
        DateTime.utc_now()
        |> DateTime.add(-8, :day)
        |> DateTime.truncate(:second)

      {:ok, expired_invitation} =
        Repo.update(Ecto.Changeset.change(expired_invitation, expires_at: expired_at))

      # Create a valid invitation
      %{invitation: valid_invitation} =
        invitation_fixture(owner, organization, "valid@example.com")

      # Create an accepted invitation
      %{invitation: accepted_invitation} =
        invitation_fixture(owner, organization, "accepted@example.com")

      {:ok, accepted_invitation} =
        Repo.update(
          Ecto.Changeset.change(accepted_invitation,
            accepted_at: DateTime.utc_now(:second)
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
      assert {1, nil} = Invitations.delete_expired_invitations()

      assert is_nil(Repo.get(Invitation, expired_invitation.id))
      assert Repo.get(Invitation, valid_invitation.id)
      assert Repo.get(Invitation, accepted_invitation.id)
    end

    test "returns 0 when no expired invitations exist" do
      # First, delete the expired invitation
      Invitations.delete_expired_invitations()

      # Now, there should be no expired invitations left
      assert {0, nil} = Invitations.delete_expired_invitations()
    end

    test "doesn't delete accepted invitations even if they're expired", %{
      accepted_invitation: accepted_invitation
    } do
      # Make the accepted invitation expired
      expired_at =
        DateTime.utc_now()
        |> DateTime.add(-8, :day)
        |> DateTime.truncate(:second)

      {:ok, _} = Repo.update(Ecto.Changeset.change(accepted_invitation, expires_at: expired_at))

      Invitations.delete_expired_invitations()

      assert Repo.get(Invitation, accepted_invitation.id)
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
               Invitations.accept_invitation(invitation, user_params)

      # Try to accept again (should fail)
      assert {:error, :already_accepted} =
               Invitations.accept_invitation(updated_invitation, user_params)
    end

    test "deleting the inviter doesn't delete their invitations", %{
      admin: admin,
      organization: organization
    } do
      %{invitation: invitation} = invitation_fixture(admin, organization, "example@email.com")

      assert invitation.inviter_id == admin.id
      Repo.delete(admin)

      updated_invitation = Repo.get(Invitation, invitation.id)
      assert updated_invitation.inviter_id == nil
    end
  end
end
