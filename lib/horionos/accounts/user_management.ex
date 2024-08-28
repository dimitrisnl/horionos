defmodule Horionos.Accounts.UserManagement do
  @moduledoc """
  Handles user management operations that are not directly related to authentication or email.

  This module is responsible for:
  - User registration and profile management
  - Retrieving user information
  - Managing user account statuses (e.g., locking/unlocking accounts)
  - Handling user-related database operations

  It provides a set of functions to create, update, and query user records,
  as well as manage the lifecycle of user accounts within the system.
  """
  import Ecto.Query

  alias Horionos.Accounts.User
  alias Horionos.AdminNotifications
  alias Horionos.Repo

  @unconfirmed_email_lock_deadline_in_days Application.compile_env(
                                             :horionos,
                                             :unconfirmed_email_lock_deadline_in_days
                                           )

  @type user_attrs :: %{
          required(:email) => String.t(),
          required(:password) => String.t(),
          optional(atom()) => any()
        }
  @type user_or_nil :: User.t() | nil
  @type user_operation_result :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @spec get_user_by_id!(integer()) :: User.t()
  def get_user_by_id!(id), do: Repo.get!(User, id)

  @spec get_user_by_email(String.t()) :: user_or_nil()
  def get_user_by_email(email) when is_binary(email), do: Repo.get_by(User, email: email)

  @spec register_user(user_attrs()) :: user_operation_result()
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, user} = result ->
        AdminNotifications.notify(:user_registered, user)
        result

      error ->
        error
    end
  end

  @spec build_registration_changeset(User.t(), map()) :: Ecto.Changeset.t()
  def build_registration_changeset(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  @spec build_full_name_changeset(User.t(), map()) :: Ecto.Changeset.t()
  def build_full_name_changeset(user, attrs \\ %{}) do
    User.full_name_changeset(user, attrs)
  end

  @spec update_user_full_name(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user_full_name(user, attrs) do
    user
    |> User.full_name_changeset(attrs)
    |> Repo.update()
  end

  @spec user_locked?(User.t()) :: boolean()
  def user_locked?(user) do
    !is_nil(user.locked_at)
  end

  @spec lock_user(User.t()) :: user_operation_result()
  def lock_user(user) do
    now = truncate_datetime(DateTime.utc_now())

    user
    |> Ecto.Changeset.change(locked_at: now)
    |> Repo.update()
  end

  @spec unlock_user(User.t()) :: user_operation_result()
  def unlock_user(user) do
    user
    |> Ecto.Changeset.change(locked_at: nil)
    |> Repo.update()
  end

  @doc """
  Locks all unverified user accounts that were created more than a month ago.
  Returns the number of accounts locked.
  """
  @spec lock_expired_unverified_accounts() :: {integer(), [User.t()]}
  def lock_expired_unverified_accounts do
    now = truncate_datetime(DateTime.utc_now())
    lock_threshold = DateTime.add(now, -@unconfirmed_email_lock_deadline_in_days, :day)

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

  # Private functions

  @spec truncate_datetime(DateTime.t()) :: DateTime.t()
  defp truncate_datetime(datetime) do
    DateTime.truncate(datetime, :second)
  end
end
