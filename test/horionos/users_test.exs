defmodule Horionos.UsersTest do
  use Horionos.DataCase, async: true

  import Horionos.AccountsFixtures

  alias Horionos.Accounts.Schemas.EmailToken
  alias Horionos.Accounts.Schemas.SessionToken
  alias Horionos.Accounts.Schemas.User
  alias Horionos.Accounts.Sessions
  alias Horionos.Accounts.Users

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Users.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} = Users.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      assert {:error, :user_not_found} =
               Users.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()

      assert {:error, :invalid_password} =
               Users.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture()

      assert {:ok, %User{id: ^id}} =
               Users.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "register_user/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Users.register_user(%{})

      errors = errors_on(changeset)

      assert "can't be blank" in errors.email
      assert "can't be blank" in errors.password
    end

    test "validates email and password when given" do
      {:error, changeset} = Users.register_user(%{email: "not valid", password: "not valid"})

      errors = errors_on(changeset)

      assert "must have the @ sign and no spaces" in errors.email
      assert "should be at least 12 character(s)" in errors.password
    end

    test "validates maximum values for email and password for security" do
      too_long_string = String.duplicate("db", 100)

      {:error, changeset} =
        Users.register_user(%{email: too_long_string, password: too_long_string})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Users.register_user(%{email: email})

      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Users.register_user(%{email: String.upcase(email)})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users with a hashed password" do
      email = unique_user_email()
      {:ok, user} = Users.register_user(valid_user_attributes(email: email))
      assert user.email == email
      assert is_binary(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end
  end

  describe "build_registration_changeset/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Users.build_registration_changeset(%User{})
      assert changeset.required == [:password, :email, :full_name]
    end

    test "allows fields to be set" do
      email = unique_user_email()
      password = valid_user_password()
      full_name = valid_user_full_name()

      changeset =
        Users.build_registration_changeset(
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

  describe "build_full_name_changeset/2" do
    test "returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = changeset = Users.build_full_name_changeset(user)
      assert changeset.required == [:full_name]
    end

    test "allows full_name to be set" do
      user = user_fixture()
      new_full_name = "New Full Name"
      changeset = Users.build_full_name_changeset(user, %{full_name: new_full_name})

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
      {:ok, updated_user} = Users.update_user_full_name(user, %{full_name: new_full_name})

      assert updated_user.full_name == new_full_name
      assert Repo.get!(User, user.id).full_name == new_full_name
    end

    test "returns error changeset for invalid data", %{user: user} do
      {:error, changeset} = Users.update_user_full_name(user, %{full_name: ""})

      assert %{full_name: ["can't be blank"]} = errors_on(changeset)
      assert user.full_name == Repo.get!(User, user.id).full_name
    end
  end

  describe "user locking" do
    test "lock_user/1 sets locked_at timestamp" do
      user = user_fixture()
      {:ok, locked_user} = Users.lock_user(user)
      assert locked_user.locked_at
    end

    test "unlock_user/1 clears locked_at timestamp" do
      user = user_fixture()

      locked_user =
        Repo.update!(Ecto.Changeset.change(user, locked_at: DateTime.utc_now(:second)))

      {:ok, unlocked_user} = Users.unlock_user(locked_user)
      refute unlocked_user.locked_at
    end

    test "user_locked?/1 returns true for locked users" do
      user = user_fixture()

      locked_user =
        Repo.update!(Ecto.Changeset.change(user, locked_at: DateTime.utc_now(:second)))

      assert Users.user_locked?(locked_user)
    end

    test "user_locked?/1 returns false for unlocked users" do
      user = user_fixture()
      refute Users.user_locked?(user)
    end
  end

  describe "lock_expired_unverified_accounts/0" do
    test "locks unverified accounts past deadline" do
      past_deadline =
        DateTime.utc_now()
        |> DateTime.add(-31, :day)
        |> DateTime.truncate(:second)

      user1 =
        user_fixture()
        |> then(
          &Repo.update!(Ecto.Changeset.change(&1, inserted_at: past_deadline, confirmed_at: nil))
        )

      user2 =
        user_fixture()
        |> then(
          &Repo.update!(Ecto.Changeset.change(&1, inserted_at: past_deadline, confirmed_at: nil))
        )

      _user3 =
        user_fixture()
        |> then(
          &Repo.update!(
            Ecto.Changeset.change(&1,
              confirmed_at: NaiveDateTime.utc_now(:second)
            )
          )
        )

      # This one has a future deadline by default
      _user4 = user_fixture()

      {locked_count, locked_users} = Users.lock_expired_unverified_accounts()
      assert locked_count == 2

      sorted_locked_ids =
        locked_users
        |> Enum.map(& &1.id)
        |> Enum.sort()

      expected_ids = [user1.id, user2.id] |> Enum.sort()

      assert sorted_locked_ids == expected_ids
    end

    test "doesn't lock already locked accounts" do
      past_deadline =
        DateTime.utc_now()
        |> DateTime.add(-31, :day)
        |> DateTime.truncate(:second)

      _user1 =
        unconfirmed_user_fixture()
        |> then(
          &Repo.update!(
            Ecto.Changeset.change(&1,
              confirmed_at: nil,
              inserted_at: past_deadline,
              locked_at: DateTime.utc_now(:second)
            )
          )
        )

      user2 =
        unconfirmed_user_fixture()
        |> then(&Repo.update!(Ecto.Changeset.change(&1, inserted_at: past_deadline)))

      # This one has a future deadline by default
      _user3 = unconfirmed_user_fixture()

      {locked_count, locked_users} = Users.lock_expired_unverified_accounts()
      assert locked_count == 1
      assert Enum.map(locked_users, & &1.id) == [user2.id]
    end
  end

  describe "build_email_changeset/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Users.build_email_changeset(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_email_change/3" do
    setup do
      %{user: user_fixture()}
    end

    test "requires email to change", %{user: user} do
      {:error, changeset} = Users.apply_email_change(user, valid_user_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{user: user} do
      {:error, changeset} =
        Users.apply_email_change(user, valid_user_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Users.apply_email_change(user, valid_user_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{user: user} do
      %{email: email} = user_fixture()
      password = valid_user_password()

      {:error, changeset} = Users.apply_email_change(user, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Users.apply_email_change(user, "invalid", %{email: unique_user_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{user: user} do
      email = unique_user_email()
      {:ok, user} = Users.apply_email_change(user, valid_user_password(), %{email: email})
      assert user.email == email

      assert is_nil(Users.get_user_by_email(email))
    end
  end

  describe "email verification" do
    test "email_verified?/1 returns true for confirmed users" do
      user = unconfirmed_user_fixture()

      updated_user =
        Repo.update!(
          Ecto.Changeset.change(user,
            confirmed_at: NaiveDateTime.utc_now(:second)
          )
        )

      assert Users.email_verified?(updated_user)
    end

    test "email_verified?/1 returns false for unconfirmed users" do
      user = unconfirmed_user_fixture()
      refute Users.email_verified?(user)
    end
  end

  describe "build_password_changeset/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Users.build_password_changeset(%User{}, %{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Users.build_password_changeset(%User{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_password/3" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Users.update_password(user, valid_user_password(), %{
          password: "not valid"
        })

      assert %{
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Users.update_password(user, valid_user_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Users.update_password(user, "invalid", %{password: valid_user_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{user: user} do
      {:ok, user} =
        Users.update_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      assert is_nil(user.password)
      assert Users.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Sessions.create_session(user)

      {:ok, _} =
        Users.update_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(EmailToken, user_id: user.id)
      refute Repo.get_by(SessionToken, user_id: user.id)
    end
  end

  describe "valid_password?/2" do
    setup do
      %{user: user_fixture()}
    end

    test "returns true for a valid password", %{user: user} do
      assert Users.valid_password?(user, valid_user_password())
    end

    test "returns false for an invalid password", %{user: user} do
      refute Users.valid_password?(user, "invalid")
    end
  end
end
