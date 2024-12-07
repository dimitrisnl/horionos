defmodule HorionosWeb.Organization.InvitationsLiveTest do
  use HorionosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Horionos.AccountsFixtures
  import Horionos.OrganizationsFixtures
  import Horionos.InvitationsFixtures
  import Horionos.MembershipsFixtures

  alias Horionos.Invitations.Invitations
  alias Horionos.Memberships.Memberships
  alias Horionos.Memberships.Schemas.Membership
  alias Horionos.Repo

  describe "Invitations page" do
    setup do
      owner = user_fixture()
      organization = organization_fixture(%{user: owner})

      admin = user_fixture()
      membership_fixture(%{user_id: admin.id, organization_id: organization.id, role: :admin})

      member = user_fixture()
      membership_fixture(%{user_id: member.id, organization_id: organization.id, role: :member})

      %{owner: owner, admin: admin, member: member, organization: organization}
    end

    test "renders invitation page", %{conn: conn, owner: owner, organization: organization} do
      %{invitation: invitation} = invitation_fixture(owner, organization, "test@example.com")

      conn = log_in_user(conn, owner)

      {:ok, _view, html} = live(conn, ~p"/organization/invitations")

      assert html =~ "Invite a new member"
      assert html =~ "Invitations"
      assert html =~ "Email"
      assert html =~ "Role"

      assert html =~ invitation.email
      assert html =~ to_string(invitation.role)
      assert html =~ "Pending"
    end

    test "can send a new invitation", %{conn: conn, owner: owner, organization: organization} do
      conn = log_in_user(conn, owner)

      {:ok, view, _html} = live(conn, ~p"/organization/invitations")

      assert view
             |> form("#invitation_form",
               invitation: %{email: "newinvite@example.com", role: "member"}
             )
             |> render_submit()

      assert_redirect(view, ~p"/organization/invitations")

      # Verify the invitation was created
      {:ok, invitations} = Invitations.list_pending_organization_invitations(organization)
      assert [invitation] = invitations
      assert invitation.email == "newinvite@example.com"
      assert invitation.role == :member
    end

    test "shows error for invalid invitation", %{conn: conn, owner: owner} do
      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/organization/invitations")

      assert view
             |> form("#invitation_form", invitation: %{email: "invalid-email", role: "member"})
             |> render_submit() =~ "must have the @ sign and no spaces"
    end

    test "can cancel a pending invitation", %{
      conn: conn,
      owner: owner,
      organization: organization
    } do
      invitation = invitation_fixture(owner, organization, "cancel@example.com")

      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/organization/invitations")

      assert view
             |> element("a", "Cancel")
             |> render_click()

      refute render(view) =~ "cancel@example.com"

      assert {:error, :invalid_token} =
               Invitations.get_pending_invitation_by_token(invitation.token)
    end

    test "non-admin users cannot access invitations page", %{
      conn: conn,
      organization: organization
    } do
      non_admin = user_fixture()

      Memberships.create_membership(%{
        user_id: non_admin.id,
        organization_id: organization.id,
        role: :member
      })

      conn = log_in_user(conn, non_admin)

      assert {:error,
              {:live_redirect,
               %{to: "/", flash: %{"error" => "You are not authorized to view this page"}}}} =
               live(conn, ~p"/organization/invitations")
    end

    test "handles unauthorized invitation creation", %{conn: conn, owner: owner} do
      # Simulate a scenario where the owner loses admin rights after loading the page
      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/organization/invitations")

      # Remove admin rights
      membership = Repo.get_by(Membership, user_id: owner.id)
      Memberships.update_membership_role(membership, %{role: :member})

      assert view
             |> form("#invitation_form",
               invitation: %{email: "unauthorized@example.com", role: "member"}
             )
             |> render_submit() =~ "You are not authorized to invite users to this organization"
    end

    test "handles unauthorized invitation cancellation", %{
      conn: conn,
      owner: owner,
      organization: organization
    } do
      invitation_fixture(owner, organization, "example@test/com")

      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/organization/invitations")

      # Remove admin rights
      membership = Repo.get_by(Membership, user_id: owner.id)

      Memberships.update_membership_role(membership, %{role: :member})

      assert view
             |> element("a", "Cancel")
             |> render_click() =~ "You are not authorized to cancel this invitation"
    end

    test "displays who invited the user", %{
      owner: owner,
      admin: admin,
      conn: conn,
      organization: organization
    } do
      invitation_fixture(admin, organization, "test@example.com")

      conn = log_in_user(conn, owner)
      {:ok, _view, html} = live(conn, ~p"/organization/invitations")

      # Show who created the invitation
      assert html =~ admin.full_name
      refute html =~ "Deleted user"

      # Delete/kick the admin user
      Repo.delete(admin)

      {:ok, _view, html} = live(conn, ~p"/organization/invitations")

      refute html =~ admin.email
      assert html =~ "Deleted user"
    end
  end
end
