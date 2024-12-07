defmodule HorionosWeb.Auth.UserConfirmationInstructionsLiveTest do
  use HorionosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Horionos.AccountsFixtures

  alias Horionos.Accounts.Schemas.EmailToken
  alias Horionos.Repo

  describe "Resend confirmation" do
    test "renders the resend confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/confirm")
      assert html =~ "Resend confirmation instructions"
      assert html =~ "Email"
    end

    test "sends a new confirmation token", %{conn: conn} do
      user = unconfirmed_user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/confirm")

      html =
        lv
        |> form("#resend_confirmation_form", user: %{email: user.email})
        |> render_submit()

      assert html =~ "Confirmation instructions sent"

      assert html =~
               "You will receive an email with instructions shortly. Please check your email inbox and follow the instructions to confirm your account."

      assert Repo.get_by!(EmailToken, user_id: user.id).context == "confirm"
    end

    test "does not send confirmation token if user is confirmed", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/confirm")

      html =
        lv
        |> form("#resend_confirmation_form", user: %{email: user.email})
        |> render_submit()

      assert html =~ "Confirmation instructions sent"

      assert html =~
               "You will receive an email with instructions shortly. Please check your email inbox and follow the instructions to confirm your account."

      user_email = user.email
      refute_received {:email, %{to: [^user_email]}}
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/confirm")

      html =
        lv
        |> form("#resend_confirmation_form", user: %{email: "unknown@example.com"})
        |> render_submit()

      assert html =~ "Confirmation instructions sent"

      assert html =~
               "You will receive an email with instructions shortly. Please check your email inbox and follow the instructions to confirm your account."

      assert Repo.all(EmailToken) == []
    end
  end
end
