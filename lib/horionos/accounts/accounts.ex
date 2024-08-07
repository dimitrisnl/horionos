defmodule Horionos.Accounts do
  @moduledoc """
  The Accounts context.
  Handles user-related operations including registration, authentication,
  and user profile management.
  """

  import Ecto.Query

  alias Horionos.Repo
  alias Horionos.Accounts.{EmailToken, SessionToken, User}
  alias Horionos.AdminNotifications
  alias Horionos.UserNotifications

  @unconfirmed_email_lock_deadline_in_days Application.compile_env(
                                             :horionos,
                                             :unconfirmed_email_lock_deadline_in_days
                                           )

  @unconfirmed_email_deadline_in_days Application.compile_env(
                                        :horionos,
                                        :unconfirmed_email_deadline_in_days
                                      )

  @type user_attrs :: %{
          required(:email) => String.t(),
          required(:password) => String.t(),
          optional(atom()) => any()
        }
  @type user_or_nil :: User.t() | nil
  @type user_operation_result :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Gets a user by ID.
  """
  @spec get_user!(integer()) :: User.t()
  #
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a user by email.
  """
  @spec get_user_by_email(String.t()) :: user_or_nil()
  #
  def get_user_by_email(email) when is_binary(email), do: Repo.get_by(User, email: email)

  @doc """
  Gets a user by email and password.
  """
  @spec get_user_by_email_and_password(String.t(), String.t()) :: user_or_nil()
  #
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Registers a user.
  """
  @spec register_user(user_attrs()) :: user_operation_result()
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> tap(fn
      {:ok, user} ->
        AdminNotifications.notify(:user_registered, user)

      _ ->
        :ok
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  @spec change_user_registration(User.t(), map()) :: Ecto.Changeset.t()
  #
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  @spec change_user_full_name(User.t(), map()) :: Ecto.Changeset.t()
  #
  def change_user_full_name(user, attrs \\ %{}) do
    User.full_name_changeset(user, attrs)
  end

  @spec update_user_full_name(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  #
  def update_user_full_name(user, attrs) do
    user
    |> User.full_name_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.
  """
  @spec change_user_email(User.t(), map()) :: Ecto.Changeset.t()
  #
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Emulates applying the email change without actually changing
  it in the database.
  """
  @spec apply_user_email(User.t(), String.t(), map()) :: user_operation_result()
  #
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.
  """
  @spec update_user_email(User.t(), String.t()) :: :ok | :error
  #
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- EmailToken.verify_change_email_token_query(token, context),
         %EmailToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  @doc """
  Delivers the update email instructions to the given user.
  """
  @spec deliver_user_update_email_instructions(User.t(), String.t(), (String.t() -> String.t())) ::
          {:ok, map()} | {:error, any()}
  #
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = EmailToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)

    UserNotifications.deliver_update_email_instructions(
      user,
      update_email_url_fun.(encoded_token)
    )
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.
  """
  @spec change_user_password(User.t(), map()) :: Ecto.Changeset.t()
  #
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.
  """
  @spec update_user_password(User.t(), String.t(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  #
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:session_tokens, SessionToken.by_user_query(user))
    |> Ecto.Multi.delete_all(:tokens, EmailToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Generates a session token.
  """
  #
  @spec generate_user_session_token(User.t(), map() | nil) :: String.t()
  #
  def generate_user_session_token(user, device_info \\ nil) do
    {token, user_token} = SessionToken.build_session_token(user, device_info)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  @spec get_user_by_session_token(String.t()) :: User.t() | nil
  #
  def get_user_by_session_token(token) do
    {:ok, query} = SessionToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  @spec delete_user_session_token(String.t()) :: :ok
  #
  def delete_user_session_token(token) do
    Repo.delete_all(SessionToken.by_token_query(token))
    :ok
  end

  @doc """
  Delivers the confirmation email instructions to the given user.
  """
  @spec deliver_user_confirmation_instructions(User.t(), (String.t() -> String.t())) ::
          {:ok, map()} | {:error, :already_confirmed}
  #
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = EmailToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)

      UserNotifications.deliver_confirmation_instructions(
        user,
        confirmation_url_fun.(encoded_token)
      )
    end
  end

  @doc """
  Confirms a user by the given token.
  """
  @spec confirm_user(String.t()) :: {:ok, User.t()} | :error
  #
  def confirm_user(token) do
    with {:ok, query} <- EmailToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  @doc """
  Delivers the reset password email to the given user.
  """
  @spec deliver_user_reset_password_instructions(User.t(), (String.t() -> String.t())) ::
          {:ok, map()} | {:error, any()}
  #
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = EmailToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)

    UserNotifications.deliver_reset_password_instructions(
      user,
      reset_password_url_fun.(encoded_token)
    )
  end

  @doc """
  Gets the user by reset password token.
  """
  @spec get_user_by_reset_password_token(String.t()) :: User.t() | nil
  #
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- EmailToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.
  """
  @spec reset_user_password(User.t(), map()) :: user_operation_result()
  #
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:session_tokens, SessionToken.by_user_query(user))
    |> Ecto.Multi.delete_all(:tokens, EmailToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @spec email_verified?(User.t()) :: boolean()
  #
  def email_verified?(user) do
    !is_nil(user.confirmed_at)
  end

  @spec email_verification_deadline(User.t()) :: DateTime.t()
  #
  def email_verification_deadline(%User{} = user) do
    DateTime.add(user.inserted_at, @unconfirmed_email_deadline_in_days, :day)
  end

  @spec email_verification_pending?(User.t()) :: boolean()
  #
  def email_verification_pending?(user) do
    now = truncate_datetime(DateTime.utc_now())

    is_nil(user.confirmed_at) &&
      DateTime.compare(email_verification_deadline(user), now) == :gt
  end

  @spec user_email_verified_or_pending?(User.t()) :: boolean()
  #
  def user_email_verified_or_pending?(user) do
    email_verified?(user) || email_verification_pending?(user)
  end

  @spec lock_user(User.t()) :: user_operation_result()
  #
  def lock_user(user) do
    now = truncate_datetime(DateTime.utc_now())

    user
    |> Ecto.Changeset.change(locked_at: now)
    |> Repo.update()
  end

  @spec unlock_user(User.t()) :: user_operation_result()
  #
  def unlock_user(user) do
    user
    |> Ecto.Changeset.change(locked_at: nil)
    |> Repo.update()
  end

  @spec user_locked?(User.t()) :: boolean()
  #
  def user_locked?(user) do
    !is_nil(user.locked_at)
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

  @spec get_user_sessions(User.t(), String.t()) :: [map()]
  #
  def get_user_sessions(user, current_token) do
    SessionToken.by_user_query(user)
    |> select([st], %{
      id: st.id,
      device: st.device,
      os: st.os,
      browser: st.browser,
      browser_version: st.browser_version,
      inserted_at: st.inserted_at,
      is_current: st.token == ^current_token
    })
    |> Repo.all()
  end

  @spec clear_user_sessions(User.t(), String.t()) :: {integer(), nil | [term()]}
  #
  def clear_user_sessions(user, current_token) do
    SessionToken.by_user_query(user)
    |> where([st], st.token != ^current_token)
    |> Repo.delete_all()
  end

  # Private functions

  @spec user_email_multi(User.t(), String.t(), String.t()) :: Ecto.Multi.t()
  #
  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, EmailToken.by_user_and_contexts_query(user, [context]))
  end

  @spec confirm_user_multi(User.t()) :: Ecto.Multi.t()
  #
  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, EmailToken.by_user_and_contexts_query(user, ["confirm"]))
  end

  @spec truncate_datetime(DateTime.t()) :: DateTime.t()
  #
  defp truncate_datetime(datetime) do
    DateTime.truncate(datetime, :second)
  end
end
