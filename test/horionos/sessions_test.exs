defmodule Horionos.AccountsTest do
  use Horionos.DataCase, async: true

  import Horionos.AccountsFixtures

  alias Horionos.Accounts.Schemas.SessionToken
  alias Horionos.Accounts.Sessions

  describe "create_session/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Sessions.create_session(user)
      assert user_token = Repo.get_by(SessionToken, token: token)

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%SessionToken{
          token: user_token.token,
          user_id: user_fixture().id
        })
      end
    end
  end

  describe "get_session_user/1" do
    setup do
      user = user_fixture()
      token = Sessions.create_session(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Sessions.get_session_user(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Sessions.get_session_user("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(SessionToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Sessions.get_session_user(token)
    end
  end

  describe "revoke_session/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Sessions.create_session(user)
      assert Sessions.revoke_session(token) == :ok
      refute Sessions.get_session_user(token)
    end
  end

  describe "list_sessions/2" do
    # Todo: Implement this test
  end

  describe "revoke_other_sessions/2" do
    # Todo: Implement this test
  end
end
