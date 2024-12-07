defmodule Horionos.EmailVerificationTest do
  use Horionos.DataCase, async: true

  import Horionos.AccountsFixtures

  alias Horionos.Accounts.EmailVerification
  alias Horionos.Accounts.Schemas.EmailToken
  alias Horionos.Accounts.Schemas.User

  describe "initiate_email_change/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      new_email = "current@example.com"

      token =
        extract_user_token(fn url ->
          EmailVerification.initiate_email_change(user, new_email, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(EmailToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      # Changed: Check for new email
      assert user_token.sent_to == new_email
      # Check full context
      assert user_token.context == "change:#{user.email}"
    end
  end

  describe "complete_email_change/2" do
    setup do
      user = user_fixture()
      new_email = unique_user_email()

      token =
        extract_user_token(fn url ->
          EmailVerification.initiate_email_change(user, new_email, url)
        end)

      %{user: user, token: token, email: new_email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: new_email} do
      assert EmailVerification.complete_email_change(user, token) == :ok
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == new_email
      assert changed_user.confirmed_at == user.confirmed_at
      refute Repo.get_by(EmailToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert EmailVerification.complete_email_change(user, "oops") == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(EmailToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert EmailVerification.complete_email_change(
               %{user | email: "current@example.com"},
               token
             ) ==
               :error

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(EmailToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(EmailToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert EmailVerification.complete_email_change(user, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(EmailToken, user_id: user.id)
    end
  end

  describe "send_confirmation_instructions/2" do
    test "sends token through notification" do
      user = unconfirmed_user_fixture()

      token =
        extract_user_token(fn url ->
          EmailVerification.send_confirmation_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(EmailToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "confirm"
    end
  end

  describe "confirm_email/1" do
    setup do
      user = unconfirmed_user_fixture()

      token =
        extract_user_token(fn url ->
          EmailVerification.send_confirmation_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "confirms the email with a valid token", %{user: user, token: token} do
      assert {:ok, confirmed_user} = EmailVerification.confirm_email(token)
      assert confirmed_user.confirmed_at
      assert confirmed_user.confirmed_at != user.confirmed_at
      assert Repo.get!(User, user.id).confirmed_at
      refute Repo.get_by(EmailToken, user_id: user.id)
    end

    test "does not confirm with invalid token", %{user: user} do
      assert EmailVerification.confirm_email("oops") == {:error, :invalid_token}
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(EmailToken, user_id: user.id)
    end

    test "does not confirm email if token expired", %{user: user, token: token} do
      Repo.update_all(EmailToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert EmailVerification.confirm_email(token) == {:error, :invalid_token}
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(EmailToken, user_id: user.id)
    end
  end
end
