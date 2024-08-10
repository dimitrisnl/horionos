defmodule Horionos.AccountsTest do
  use Horionos.DataCase

  alias Horionos.Accounts
  alias Horionos.Accounts.{EmailToken, SessionToken, User}

  import Horionos.AccountsFixtures

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "register_user/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_user(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts.register_user(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_user(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.register_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users with a hashed password" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_user(valid_user_attributes(email: email))
      assert user.email == email
      assert is_binary(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end
  end

  describe "build_registration_changeset/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.build_registration_changeset(%User{})
      assert changeset.required == [:password, :email, :full_name]
    end

    test "allows fields to be set" do
      email = unique_user_email()
      password = valid_user_password()
      full_name = valid_user_full_name()

      changeset =
        Accounts.build_registration_changeset(
          %User{},
          valid_user_attributes(email: email, password: password, full_name: full_name)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert get_change(changeset, :full_name) == full_name
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "build_email_changeset/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.build_email_changeset(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "build_full_name_changeset/2" do
    test "returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = changeset = Accounts.build_full_name_changeset(user)
      assert changeset.required == [:full_name]
    end

    test "allows full_name to be set" do
      user = user_fixture()
      new_full_name = "New Full Name"
      changeset = Accounts.build_full_name_changeset(user, %{full_name: new_full_name})

      assert changeset.valid?
      assert get_change(changeset, :full_name) == new_full_name
    end
  end

  describe "update_user_full_name/2" do
    setup do
      %{user: user_fixture()}
    end

    test "updates the full_name", %{user: user} do
      new_full_name = "New Full Name"
      {:ok, updated_user} = Accounts.update_user_full_name(user, %{full_name: new_full_name})

      assert updated_user.full_name == new_full_name
      assert Repo.get!(User, user.id).full_name == new_full_name
    end

    test "returns error changeset for invalid data", %{user: user} do
      {:error, changeset} = Accounts.update_user_full_name(user, %{full_name: ""})

      assert %{full_name: ["can't be blank"]} = errors_on(changeset)
      assert user.full_name == Repo.get!(User, user.id).full_name
    end
  end

  describe "apply_email_change/3" do
    setup do
      %{user: user_fixture()}
    end

    test "requires email to change", %{user: user} do
      {:error, changeset} = Accounts.apply_email_change(user, valid_user_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{user: user} do
      {:error, changeset} =
        Accounts.apply_email_change(user, valid_user_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_email_change(user, valid_user_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{user: user} do
      %{email: email} = user_fixture()
      password = valid_user_password()

      {:error, changeset} = Accounts.apply_email_change(user, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.apply_email_change(user, "invalid", %{email: unique_user_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{user: user} do
      email = unique_user_email()
      {:ok, user} = Accounts.apply_email_change(user, valid_user_password(), %{email: email})
      assert user.email == email

      assert is_nil(Accounts.get_user_by_email(email))
    end
  end

  describe "deliver_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.send_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(EmailToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.send_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert Accounts.update_user_email(user, token) == :ok
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      assert changed_user.confirmed_at
      assert changed_user.confirmed_at != user.confirmed_at
      refute Repo.get_by(EmailToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(EmailToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(EmailToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(EmailToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_user_email(user, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(EmailToken, user_id: user.id)
    end
  end

  describe "build_password_changeset/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.build_password_changeset(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.build_password_changeset(%User{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/3" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, valid_user_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, "invalid", %{password: valid_user_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{user: user} do
      {:ok, user} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.create_session_token(user)

      {:ok, _} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(EmailToken, user_id: user.id)
      refute Repo.get_by(SessionToken, user_id: user.id)
    end
  end

  describe "create_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.create_session_token(user)
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

  describe "get_user_from_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.create_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_from_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_from_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(SessionToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_from_session_token(token)
    end
  end

  describe "revoke_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.create_session_token(user)
      assert Accounts.revoke_session_token(token) == :ok
      refute Accounts.get_user_from_session_token(token)
    end
  end

  describe "send_confirmation_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.send_confirmation_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(EmailToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "confirm"
    end
  end

  describe "confirm_user_email/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.send_confirmation_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "confirms the email with a valid token", %{user: user, token: token} do
      assert {:ok, confirmed_user} = Accounts.confirm_user_email(token)
      assert confirmed_user.confirmed_at
      assert confirmed_user.confirmed_at != user.confirmed_at
      assert Repo.get!(User, user.id).confirmed_at
      refute Repo.get_by(EmailToken, user_id: user.id)
    end

    test "does not confirm with invalid token", %{user: user} do
      assert Accounts.confirm_user_email("oops") == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(EmailToken, user_id: user.id)
    end

    test "does not confirm email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(EmailToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_user_email(token) == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(EmailToken, user_id: user.id)
    end
  end

  describe "send_reset_password_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.send_reset_password_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(EmailToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "reset_password"
    end
  end

  describe "get_user_from_reset_token/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.send_reset_password_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "returns the user with valid token", %{user: %{id: id}, token: token} do
      assert %User{id: ^id} = Accounts.get_user_from_reset_token(token)
      assert Repo.get_by(EmailToken, user_id: id)
    end

    test "does not return the user with invalid token", %{user: user} do
      refute Accounts.get_user_from_reset_token("oops")
      assert Repo.get_by(EmailToken, user_id: user.id)
    end

    test "does not return the user if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(EmailToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_from_reset_token(token)
      assert Repo.get_by(EmailToken, user_id: user.id)
    end
  end

  describe "reset_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.reset_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_user_password(user, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, updated_user} = Accounts.reset_user_password(user, %{password: "new valid password"})
      assert is_nil(updated_user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.create_session_token(user)
      {:ok, _} = Accounts.reset_user_password(user, %{password: "new valid password"})
      refute Repo.get_by(EmailToken, user_id: user.id)
      refute Repo.get_by(SessionToken, user_id: user.id)
    end
  end

  describe "email verification" do
    test "get_email_verification_deadline" do
      user = user_fixture()
      assert Accounts.get_email_verification_deadline(user) == DateTime.add(user.inserted_at, 7, :day)
    end

    test "email_verified?/1 returns true for confirmed users" do
      user = user_fixture()

      updated_user =
        Repo.update!(
          Ecto.Changeset.change(user,
            confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          )
        )

      assert Accounts.email_verified?(updated_user)
    end

    test "email_verified?/1 returns false for unconfirmed users" do
      user = user_fixture()
      refute Accounts.email_verified?(user)
    end

    test "email_verification_pending?/1 returns true for unconfirmed users within deadline" do
      user = user_fixture()
      assert Accounts.email_verification_pending?(user)
    end

    test "email_verification_pending?/1 returns false for confirmed users" do
      user = user_fixture()

      updated_user =
        Repo.update!(
          Ecto.Changeset.change(user,
            confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          )
        )

      refute Accounts.email_verification_pending?(updated_user)
    end

    test "email_verification_pending?/1 returns false for users past deadline" do
      user = user_fixture()

      updated_user =
        Repo.update!(
          Ecto.Changeset.change(user,
            inserted_at:
              DateTime.utc_now() |> DateTime.add(-40, :day) |> DateTime.truncate(:second)
          )
        )

      refute Accounts.email_verification_pending?(updated_user)
    end

    test "email_verified_or_pending?/1 returns true for confirmed users" do
      user = user_fixture()

      updated_user =
        Repo.update!(
          Ecto.Changeset.change(user,
            confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          )
        )

      assert Accounts.email_verified_or_pending?(updated_user)
    end

    test "email_verified_or_pending?/1 returns true for unconfirmed users within deadline" do
      user = user_fixture()
      assert Accounts.email_verified_or_pending?(user)
    end

    test "email_verified_or_pending?/1 returns false for unconfirmed users past deadline" do
      user = user_fixture()

      updated_user =
        Repo.update!(
          Ecto.Changeset.change(user,
            inserted_at:
              DateTime.utc_now() |> DateTime.add(-40, :day) |> DateTime.truncate(:second)
          )
        )

      refute Accounts.email_verified_or_pending?(updated_user)
    end
  end

  describe "user locking" do
    test "lock_user/1 sets locked_at timestamp" do
      user = user_fixture()
      {:ok, locked_user} = Accounts.lock_user(user)
      assert locked_user.locked_at
    end

    test "unlock_user/1 clears locked_at timestamp" do
      user = user_fixture()

      locked_user =
        Repo.update!(
          Ecto.Changeset.change(user, locked_at: DateTime.utc_now() |> DateTime.truncate(:second))
        )

      {:ok, unlocked_user} = Accounts.unlock_user(locked_user)
      refute unlocked_user.locked_at
    end

    test "user_locked?/1 returns true for locked users" do
      user = user_fixture()

      locked_user =
        Repo.update!(
          Ecto.Changeset.change(user, locked_at: DateTime.utc_now() |> DateTime.truncate(:second))
        )

      assert Accounts.user_locked?(locked_user)
    end

    test "user_locked?/1 returns false for unlocked users" do
      user = user_fixture()
      refute Accounts.user_locked?(user)
    end
  end

  describe "lock_expired_unverified_accounts/0" do
    test "locks unverified accounts past deadline" do
      past_deadline = DateTime.utc_now() |> DateTime.add(-31, :day) |> DateTime.truncate(:second)

      user1 =
        user_fixture()
        |> then(&Repo.update!(Ecto.Changeset.change(&1, inserted_at: past_deadline)))

      user2 =
        user_fixture()
        |> then(&Repo.update!(Ecto.Changeset.change(&1, inserted_at: past_deadline)))

      _user3 =
        user_fixture()
        |> then(
          &Repo.update!(
            Ecto.Changeset.change(&1,
              confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
            )
          )
        )

      # This one has a future deadline by default
      _user4 = user_fixture()

      {locked_count, locked_users} = Accounts.lock_expired_unverified_accounts()
      assert locked_count == 2
      assert Enum.map(locked_users, & &1.id) == [user1.id, user2.id]
    end

    test "doesn't lock already locked accounts" do
      past_deadline = DateTime.utc_now() |> DateTime.add(-31, :day) |> DateTime.truncate(:second)

      _user1 =
        user_fixture()
        |> then(
          &Repo.update!(
            Ecto.Changeset.change(&1,
              inserted_at: past_deadline,
              locked_at: DateTime.utc_now() |> DateTime.truncate(:second)
            )
          )
        )

      user2 =
        user_fixture()
        |> then(&Repo.update!(Ecto.Changeset.change(&1, inserted_at: past_deadline)))

      # This one has a future deadline by default
      _user3 = user_fixture()

      {locked_count, locked_users} = Accounts.lock_expired_unverified_accounts()
      assert locked_count == 1
      assert Enum.map(locked_users, & &1.id) == [user2.id]
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
