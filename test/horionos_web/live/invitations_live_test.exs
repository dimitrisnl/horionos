defmodule HorionosWeb.OrgLive.InvitationsTest do
  use HorionosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Horionos.AccountsFixtures
  import Horionos.OrgsFixtures

  alias Horionos.Orgs
  alias Horionos.Orgs.Membership
  alias Horionos.Repo

  describe "Invitations page" do
    setup do
      owner = user_fixture()

      admin = user_fixture()
      member = user_fixture()

      org = org_fixture(%{user: owner})
      membership_fixture(%{user_id: admin.id, org_id: org.id, role: :admin})
      membership_fixture(%{user_id: member.id, org_id: org.id, role: :member})

      %{owner: owner, admin: admin, member: member, org: org}
    end

    test "renders invitation page", %{conn: conn, owner: owner, org: org} do
      conn = log_in_user(conn, owner)
      invitation = invitation_fixture(owner, org, "test@example.com")

      {:ok, _view, html} = live(conn, ~p"/org/invitations")

      assert html =~ "Invite a new member"
      assert html =~ "Invitations"
      assert html =~ "Email"
      assert html =~ "Role"

      assert html =~ invitation.email
      assert html =~ to_string(invitation.role)
      assert html =~ "Pending"
    end

    test "can send a new invitation", %{conn: conn, owner: owner, org: org} do
      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/org/invitations")

      assert view
             |> form("#invitation_form",
               invitation: %{email: "newinvite@example.com", role: "member"}
             )
             |> render_submit()

      assert_redirect(view, ~p"/org/invitations")

      # Verify the invitation was created
      {:ok, invitations} = Orgs.list_org_invitations(org)
      assert [invitation] = invitations
      assert invitation.email == "newinvite@example.com"
      assert invitation.role == :member
    end

    test "shows error for invalid invitation", %{conn: conn, owner: owner} do
      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/org/invitations")

      assert view
             |> form("#invitation_form", invitation: %{email: "invalid-email", role: "member"})
             |> render_submit() =~ "must have the @ sign and no spaces"
    end

    test "can cancel a pending invitation", %{conn: conn, owner: owner, org: org} do
      invitation = invitation_fixture(owner, org, "cancel@example.com")
      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/org/invitations")

      assert view
             |> element("a", "Cancel")
             |> render_click()

      refute render(view) =~ "cancel@example.com"
      assert is_nil(Orgs.get_pending_invitation_by_token(invitation.token))
    end

    test "cannot cancel an accepted invitation", %{conn: conn, owner: owner, org: org} do
      invitation = invitation_fixture(owner, org, "accepted@example.com")

      Orgs.accept_invitation(invitation, %{
        full_name: "Accepted User",
        password: valid_user_password()
      })

      conn = log_in_user(conn, owner)
      {:ok, _view, html} = live(conn, ~p"/org/invitations")

      assert html =~ "accepted@example.com"
      assert html =~ "Accepted"
      refute html =~ "Cancel"
    end

    test "non-admin users cannot access invitations page", %{conn: conn, org: org} do
      non_admin = user_fixture()
      Orgs.create_membership(%{user_id: non_admin.id, org_id: org.id, role: :member})

      conn = log_in_user(conn, non_admin)

      assert {:error,
              {:live_redirect,
               %{to: "/", flash: %{"error" => "You are not authorized to view this page"}}}} =
               live(conn, ~p"/org/invitations")
    end

    test "handles unauthorized invitation creation", %{conn: conn, owner: owner} do
      # Simulate a scenario where the owner loses admin rights after loading the page
      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/org/invitations")

      # Remove admin rights
      membership = Repo.get_by(Membership, user_id: owner.id)
      Orgs.update_membership(membership, %{role: :member})

      assert view
             |> form("#invitation_form",
               invitation: %{email: "unauthorized@example.com", role: "member"}
             )
             |> render_submit() =~ "You are not authorized to invite users to this organization"
    end

    test "handles unauthorized invitation cancelation", %{conn: conn, owner: owner, org: org} do
      invitation_fixture(owner, org, "example@test/com")

      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/org/invitations")

      # Remove admin rights
      membership = Repo.get_by(Membership, user_id: owner.id)

      Orgs.update_membership(membership, %{role: :member})

      assert view
             |> element("a", "Cancel")
             |> render_click() =~ "You are not authorized to cancel this invitation"
    end
  end
end
