defmodule Horionos.Accounts.Users do
  @moduledoc """
  Module for user account management.
  """
  import Ecto.Query

  alias Horionos.Accounts.Schemas.User
  alias Horionos.Accounts.Tokens
  alias Horionos.Constants
  alias Horionos.Repo
  alias Horionos.SystemAdmin.Notifier, as: SystemAdminNotifications

  # User Retrieval
  @doc """
  Retrieves a user by their email address.

  ## Parameters
    - email: The email address to search for

  ## Returns
    - The user struct if found
    - nil if no user exists with the given email
  """
  @spec get_user_by_email(String.t()) :: User.t() | nil
  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets the user using their email and password.

  ## Parameters
    - email: The user's email address
    - password: The user's password

  ## Returns
    - {:ok, user} if the user is found and the password is valid
    - {:error, :user_not_found} if no user is found with the given email
    - {:error, :invalid_password} if the password is invalid
  """
  @spec get_user_by_email_and_password(String.t(), String.t()) ::
          {:ok, User.t()} | {:error, :user_not_found} | {:error, :invalid_password}
  def get_user_by_email_and_password(email, password) do
    with user when not is_nil(user) <- Repo.get_by(User, email: email),
         true <- User.valid_password?(user, password) do
      {:ok, user}
    else
      nil -> {:error, :user_not_found}
      false -> {:error, :invalid_password}
    end
  end

  @doc """
  Validates a user's password.

  ## Parameters
    - user: User struct to validate against
    - password: Password to validate

  ## Returns
    - true if the password is valid
    - false if the password is invalid
  """
  @spec valid_password?(User.t(), String.t()) :: boolean()
  def valid_password?(user, password) do
    User.valid_password?(user, password)
  end

  # User Registration
  @type user_registration_attrs :: %{
          required(:email) => String.t(),
          required(:password) => String.t()
        }

  @doc """
  Registers a new user account.

  ## Parameters
    - attrs: Map containing required user attributes (email, password)

  ## Returns
    - {:ok, user} if registration succeeds
    - {:error, changeset} if validation fails

  Sends a notification to system administrators upon successful registration.
  """
  @spec register_user(user_registration_attrs) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> tap(fn result ->
      case result do
        {:ok, user} ->
          SystemAdminNotifications.notify(:user_registered, user)

        _ ->
          :ok
      end
    end)
  end

  @doc """
  Builds a changeset for user registration without hashing the password or validating email.

  ## Parameters
    - user: User struct to build the changeset for
    - attrs: Attributes to apply to the changeset

  ## Returns
    - A changeset for user registration
  """
  @spec build_registration_changeset(User.empty(), map()) :: Ecto.Changeset.t()
  @spec build_registration_changeset(User.t(), map()) :: Ecto.Changeset.t()
  def build_registration_changeset(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  # Profile Management
  @doc """
  Builds a changeset for updating a user's full name.

  ## Parameters
    - user: User struct to build the changeset for
    - attrs: Attributes containing the new full name

  ## Returns
    - A changeset for updating the user's full name
  """
  @spec build_full_name_changeset(User.t(), map()) :: Ecto.Changeset.t()
  def build_full_name_changeset(user, attrs \\ %{}) do
    User.full_name_changeset(user, attrs)
  end

  @doc """
  Updates a user's full name.

  ## Parameters
    - user: User struct to update
    - attrs: Attributes containing the new full name

  ## Returns
    - {:ok, user} if update succeeds
    - {:error, changeset} if validation fails
  """
  @spec update_user_full_name(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user_full_name(user, attrs) do
    user
    |> User.full_name_changeset(attrs)
    |> Repo.update()
  end

  # Email Management
  @doc """
  Builds a changeset for updating a user's email without validation.

  ## Parameters
    - user: User struct to build the changeset for
    - attrs: Attributes containing the new email

  ## Returns
    - A changeset for updating the user's email
  """
  @spec build_email_changeset(User.t(), map()) :: Ecto.Changeset.t()
  def build_email_changeset(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Applies email change after validating the current password.

  ## Parameters
    - user: User struct to apply the change to
    - password: Current password for validation
    - attrs: Attributes containing the new email

  ## Returns
    - {:ok, user} if validation succeeds
    - {:error, changeset} if validation fails
  """
  @spec apply_email_change(User.t(), String.t(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def apply_email_change(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Checks if a user's email is verified.

  ## Parameters
    - user: User struct to check

  ## Returns
    - true if the email is verified (confirmed_at is set)
    - false if the email is not verified
  """
  @spec email_verified?(User.t()) :: boolean()
  def email_verified?(user) do
    !is_nil(user.confirmed_at)
  end

  # Password Management
  @doc """
  Builds a changeset for updating a user's password.

  ## Parameters
    - user: User struct to build the changeset for
    - attrs: Attributes containing the new password
    - opts: Options for password handling (e.g., hash_password: false)

  ## Returns
    - A changeset for updating the user's password
  """
  @spec build_password_changeset(User.t(), map(), keyword()) :: Ecto.Changeset.t()
  def build_password_changeset(user, attrs, opts \\ [hash_password: false]) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates a user's password after validating the current password.
  Invalidates all user tokens upon successful password change.

  ## Parameters
    - user: User struct to update
    - current_password: Current password for validation
    - attrs: Attributes containing the new password

  ## Returns
    - {:ok, user} if update succeeds
    - {:error, changeset} if validation fails
  """
  @spec update_password(User.t(), String.t(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_password(user, current_password, attrs) do
    user
    |> User.password_changeset(attrs)
    |> User.validate_current_password(current_password)
    |> Repo.update()
    |> tap(fn
      {:ok, updated_user} ->
        Tokens.invalidate_user_tokens(updated_user)

      _ ->
        :ok
    end)
  end

  # Account Security
  @doc """
  Locks a user account by setting the locked_at timestamp.

  ## Parameters
    - user: User struct to lock

  ## Returns
    - {:ok, user} if lock succeeds
    - {:error, changeset} if update fails
  """
  @spec lock_user(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def lock_user(user) do
    now = DateTime.utc_now(:second)

    user
    |> Ecto.Changeset.change(locked_at: now)
    |> Repo.update()
  end

  @doc """
  Unlocks a user account by clearing the locked_at timestamp.

  ## Parameters
    - user: User struct to unlock

  ## Returns
    - {:ok, user} if unlock succeeds
    - {:error, changeset} if update fails
  """
  @spec unlock_user(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def unlock_user(user) do
    user
    |> Ecto.Changeset.change(locked_at: nil)
    |> Repo.update()
  end

  @doc """
  Checks if a user account is locked.

  ## Parameters
    - user: User struct to check

  ## Returns
    - true if the account is locked (locked_at is set)
    - false if the account is not locked
  """
  @spec user_locked?(User.t()) :: boolean()
  def user_locked?(user) do
    !is_nil(user.locked_at)
  end

  @doc """
  Locks user accounts that have remained unverified beyond the configured deadline.

  ## Returns
    - {count, users} tuple where:
      - count: Number of accounts locked
      - users: List of locked user structs
  """
  @spec lock_expired_unverified_accounts() :: {integer(), [User.t()]}
  def lock_expired_unverified_accounts do
    now = DateTime.utc_now(:second)

    lock_threshold =
      DateTime.add(now, -Constants.unconfirmed_email_lock_deadline_in_days(), :day)

    query =
      from u in User,
        where:
          is_nil(u.confirmed_at) and
            u.inserted_at <= ^lock_threshold and
            is_nil(u.locked_at),
        select: u

    {locked_count, locked_users} = Repo.update_all(query, set: [locked_at: now])

    {locked_count, locked_users}
  end
end
