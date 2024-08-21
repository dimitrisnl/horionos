defmodule HorionosWeb.InvitationLive.AcceptTest do
  use HorionosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Horionos.AccountsFixtures
  import Horionos.OrgsFixtures

  alias Horionos.Orgs

  describe "Accept Invitation" do
    setup do
      owner = user_fixture()
      org = org_fixture(%{user: owner})
      invitation = invitation_fixture(owner, org, "new_user@example.com")
      %{owner: owner, org: org, invitation: invitation}
    end

    test "renders invitation accept page", %{conn: conn, invitation: invitation, org: org} do
      {:ok, _lv, html} = live(conn, ~p"/invitations/#{invitation.token}/accept")
      assert html =~ "Accept Invitation"
      assert html =~ org.title
    end

    test "allows a new user to accept invitation", %{conn: conn, invitation: invitation} do
      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invitation.token}/accept")

      form =
        form(lv, "#invitation_form", %{
          user: %{
            full_name: "New User",
            email: "new_user@example.com",
            password: valid_user_password()
          }
        })

      render_submit(form)
      assert render(lv) =~ "Accepting..."
      conn = follow_trigger_action(form, conn)
      assert redirected_to(conn) == "/"
    end

    test "allows an existing user to accept invitation", %{conn: conn, invitation: invitation} do
      user = user_fixture(email: invitation.email)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invitation.token}/accept")

      form =
        form(lv, "#invitation_form", %{})

      render_submit(form)
      assert render(lv) =~ "Accepting..."
      conn = follow_trigger_action(form, conn)
      assert redirected_to(conn) == "/"
    end

    test "shows error for invalid token", %{conn: conn} do
      {:error,
       {:redirect,
        %{to: "/users/sign_in", flash: %{"error" => "Invitation not found or already accepted"}}}} =
        live(conn, ~p"/invitations/invalid_token/accept")
    end

    test "shows error for already accepted invitation", %{conn: conn, invitation: invitation} do
      Orgs.accept_invitation(invitation, %{
        full_name: "Test User",
        password: valid_user_password()
      })

      {:error,
       {:redirect,
        %{to: "/users/sign_in", flash: %{"error" => "Invitation not found or already accepted"}}}} =
        live(conn, ~p"/invitations/#{invitation.token}/accept")
    end

    test "handles user creation failure", %{conn: conn, invitation: invitation} do
      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invitation.token}/accept")

      result =
        lv
        |> form("#invitation_form", %{
          user: %{full_name: "", email: "new_user@example.com", password: "short"}
        })
        |> render_submit()

      assert result =~ "should be at least 12 character(s)"
      assert result =~ "can&#39;t be blank"
    end

    test "handles invitation acceptance failure", %{conn: conn, invitation: invitation} do
      # Simulate a failure in accepting the invitation
      Orgs.accept_invitation(invitation, %{
        full_name: "Test User",
        password: valid_user_password()
      })

      {:error,
       {:redirect,
        %{to: "/users/sign_in", flash: %{"error" => "Invitation not found or already accepted"}}}} =
        live(conn, ~p"/invitations/#{invitation.token}/accept")
    end
  end
end
