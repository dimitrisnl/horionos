defmodule HorionosWeb.OrgLive.InvitationsTest do
  use HorionosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Horionos.AccountsFixtures
  import Horionos.OrgsFixtures

  alias Horionos.Orgs
  alias Horionos.Repo
  alias Horionos.Orgs.Membership

  describe "Invitations page" do
    setup do
      user = user_fixture()
      org = org_fixture(%{user: user})
      %{user: user, org: org}
    end

    test "renders invitations page", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/org/invitations")

      assert html =~ "Invite a new member"
      assert html =~ "Invitations"
      assert html =~ "Email"
      assert html =~ "Role"
    end

    test "lists existing invitations", %{conn: conn, user: user, org: org} do
      invitation = invitation_fixture(user, org, "test@example.com")
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/org/invitations")

      assert html =~ invitation.email
      assert html =~ to_string(invitation.role)
      assert html =~ "Pending"
    end

    test "can send a new invitation", %{conn: conn, user: user, org: org} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/org/invitations")

      assert view
             |> form("#invitation_form",
               invitation: %{email: "newinvite@example.com", role: "member"}
             )
             |> render_submit()

      assert_redirect(view, ~p"/org/invitations")

      # Verify the invitation was created
      {:ok, invitations} = Orgs.list_org_invitations(user, org)
      assert [invitation] = invitations
      assert invitation.email == "newinvite@example.com"
      assert invitation.role == :member
    end

    test "shows error for invalid invitation", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/org/invitations")

      assert view
             |> form("#invitation_form", invitation: %{email: "invalid-email", role: "member"})
             |> render_submit() =~ "must have the @ sign and no spaces"
    end

    test "can cancel a pending invitation", %{conn: conn, user: user, org: org} do
      invitation = invitation_fixture(user, org, "cancel@example.com")
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/org/invitations")

      assert view
             |> element("a", "Cancel")
             |> render_click()

      refute render(view) =~ "cancel@example.com"
      assert is_nil(Orgs.get_pending_invitation_by_token(invitation.token))
    end

    test "cannot cancel an accepted invitation", %{conn: conn, user: user, org: org} do
      invitation = invitation_fixture(user, org, "accepted@example.com")

      Orgs.accept_invitation(invitation, %{
        full_name: "Accepted User",
        password: valid_user_password()
      })

      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/org/invitations")

      assert html =~ "accepted@example.com"
      assert html =~ "Accepted"
      refute html =~ "Cancel"
    end

    test "non-admin users cannot access invitations page", %{conn: conn, user: user, org: org} do
      non_admin = user_fixture()
      Orgs.create_membership(user, %{user_id: non_admin.id, org_id: org.id, role: :member})

      conn = log_in_user(conn, non_admin)

      assert {:error,
              {:live_redirect,
               %{to: "/", flash: %{"error" => "You are not authorized to view this page"}}}} =
               live(conn, ~p"/org/invitations")
    end

    test "handles unauthorized invitation creation", %{conn: conn, user: user} do
      # Simulate a scenario where the user loses admin rights after loading the page
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/org/invitations")

      # Remove admin rights
      membership = Repo.get_by(Membership, user_id: user.id)
      Orgs.update_membership(user, membership, %{role: :member})

      assert view
             |> form("#invitation_form",
               invitation: %{email: "unauthorized@example.com", role: "member"}
             )
             |> render_submit() =~ "You are not authorized to invite users to this organization"
    end
  end
end
