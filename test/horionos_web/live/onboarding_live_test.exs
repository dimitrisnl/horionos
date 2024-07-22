defmodule HorionosWeb.OnboardingLiveTest do
  use HorionosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Horionos.Orgs

  describe "Onboarding" do
    setup :register_and_log_in_user

    @tag create_org: false
    test "renders onboarding page for user without org", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/onboarding")
      assert html =~ "Create Your Organization"
      assert html =~ "Organization Name"
    end

    @tag create_org: false
    test "creates organization with valid data", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/onboarding")

      {:ok, conn} =
        lv
        |> form("#org-form", %{title: "Test Org"})
        |> render_submit()
        |> follow_redirect(conn)

      # Check that we're redirected to the root path with an org_id
      assert conn.request_path == "/"
      assert String.match?(conn.query_string, ~r/org_id=\d+/)

      assert [org] = Orgs.list_user_orgs(user)
      assert org.title == "Test Org"
    end

    @tag create_org: false
    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/onboarding")

      result =
        lv
        |> form("#org-form", %{title: ""})
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end
  end
end
