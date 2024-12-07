defmodule Horionos.PasswordResetTest do
  use Horionos.DataCase, async: true

  import Horionos.AccountsFixtures

  alias Horionos.Accounts.PasswordReset
  alias Horionos.Accounts.Schemas.EmailToken
  alias Horionos.Accounts.Schemas.SessionToken
  alias Horionos.Accounts.Schemas.User
  alias Horionos.Accounts.Sessions
  alias Horionos.Accounts.Users

  describe "reset_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        PasswordReset.reset_password(user, %{
          password: "not valid"
        })

      assert %{
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = PasswordReset.reset_password(user, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, updated_user} = PasswordReset.reset_password(user, %{password: "new valid password"})
      assert is_nil(updated_user.password)
      assert {:ok, _} = Users.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Sessions.create_session(user)
      {:ok, _} = PasswordReset.reset_password(user, %{password: "new valid password"})
      refute Repo.get_by(EmailToken, user_id: user.id)
      refute Repo.get_by(SessionToken, user_id: user.id)
    end
  end

  describe "initiate_reset/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          PasswordReset.initiate_reset(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(EmailToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "reset_password"
    end
  end

  describe "validate_reset_token/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          PasswordReset.initiate_reset(user, url)
        end)

      %{user: user, token: token}
    end

    test "returns the user with valid token", %{user: %{id: id}, token: token} do
      assert %User{id: ^id} = PasswordReset.validate_reset_token(token)
      assert Repo.get_by(EmailToken, user_id: id)
    end

    test "does not return the user with invalid token", %{user: user} do
      refute PasswordReset.validate_reset_token("oops")
      assert Repo.get_by(EmailToken, user_id: user.id)
    end

    test "does not return the user if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(EmailToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute PasswordReset.validate_reset_token(token)
      assert Repo.get_by(EmailToken, user_id: user.id)
    end
  end
end
