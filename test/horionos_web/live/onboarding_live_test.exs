defmodule HorionosWeb.OnboardingLiveTest do
  use HorionosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Horionos.Memberships.Memberships

  describe "Onboarding" do
    setup :setup_user_pipeline

    @tag create_organization: false
    @tag confirm_user_email: true
    @tag log_in_user: true
    test "renders onboarding page for user without organization", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/onboarding")

      assert html =~ "Create Your Organization"
      assert html =~ "Organization Name"
    end

    @tag create_organization: false
    @tag confirm_user_email: true
    @tag log_in_user: true
    test "creates organization with valid data", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/onboarding")

      {:ok, conn} =
        lv
        |> form("#organization-form", %{title: "Test Organization"})
        |> render_submit()
        |> follow_redirect(conn)

      # Check that we're redirected to the root path
      assert conn.request_path == "/"

      assert {:ok, memberships} = Memberships.list_user_memberships(user)
      assert hd(memberships).organization.title == "Test Organization"
    end

    @tag create_organization: false
    @tag confirm_user_email: true
    @tag log_in_user: true
    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/onboarding")

      result =
        lv
        |> form("#organization-form", %{title: ""})
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end
  end
end
