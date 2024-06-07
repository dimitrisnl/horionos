defmodule HorionosWeb.OrgControllerTest do
  use HorionosWeb.ConnCase

  import Horionos.AccountsFixtures

  @create_attrs %{title: "some title"}
  @update_attrs %{title: "some updated title"}
  @invalid_attrs %{title: nil}

  describe "index" do
    test "lists all orgs", %{conn: conn} do
      conn = get(conn, ~p"/orgs")
      assert html_response(conn, 200) =~ "Listing Orgs"
    end
  end

  describe "new org" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/orgs/new")
      assert html_response(conn, 200) =~ "New Org"
    end
  end

  describe "create org" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/orgs", org: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/orgs/#{id}"

      conn = get(conn, ~p"/orgs/#{id}")
      assert html_response(conn, 200) =~ "Org #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/orgs", org: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Org"
    end
  end

  describe "edit org" do
    setup [:create_org]

    test "renders form for editing chosen org", %{conn: conn, org: org} do
      conn = get(conn, ~p"/orgs/#{org}/edit")
      assert html_response(conn, 200) =~ "Edit Org"
    end
  end

  describe "update org" do
    setup [:create_org]

    test "redirects when data is valid", %{conn: conn, org: org} do
      conn = put(conn, ~p"/orgs/#{org}", org: @update_attrs)
      assert redirected_to(conn) == ~p"/orgs/#{org}"

      conn = get(conn, ~p"/orgs/#{org}")
      assert html_response(conn, 200) =~ "some updated title"
    end

    test "renders errors when data is invalid", %{conn: conn, org: org} do
      conn = put(conn, ~p"/orgs/#{org}", org: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Org"
    end
  end

  describe "delete org" do
    setup [:create_org]

    test "deletes chosen org", %{conn: conn, org: org} do
      conn = delete(conn, ~p"/orgs/#{org}")
      assert redirected_to(conn) == ~p"/orgs"

      assert_error_sent 404, fn ->
        get(conn, ~p"/orgs/#{org}")
      end
    end
  end

  defp create_org(_) do
    org = org_fixture()
    %{org: org}
  end
end
