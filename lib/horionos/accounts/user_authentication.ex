defmodule Horionos.Accounts.UserAuthentication do
  @moduledoc """
  Manages user authentication, password-related operations, and session handling.

  Key responsibilities include:
  - Authenticating users (e.g., verifying email/password combinations)
  - Managing password changes and resets
  - Generating and verifying session tokens
  - Handling multi-session management for users

  This module ensures secure user authentication and session management,
  providing the necessary functions for logging users in and out, and
  maintaining the security of user sessions across the application.
  """
  import Ecto.Query

  alias Horionos.Accounts.{EmailToken, SessionToken, User}
  alias Horionos.Repo
  alias Horionos.UserNotifications

  @type user_attrs :: %{
          required(:email) => String.t(),
          required(:password) => String.t(),
          optional(atom()) => any()
        }
  @type user_or_nil :: User.t() | nil
  @type user_operation_result :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @spec get_user_by_email_and_password(String.t(), String.t()) :: user_or_nil()
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @spec build_password_changeset(User.t(), map()) :: Ecto.Changeset.t()
  def build_password_changeset(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @spec update_user_password(User.t(), String.t(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:session_tokens, SessionToken.by_user_query(user))
    |> Ecto.Multi.delete_all(:tokens, EmailToken.get_user_tokens_by_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @spec create_session_token(User.t(), map() | nil) :: String.t()
  def create_session_token(user, device_info \\ nil) do
    {token, user_token} = SessionToken.build_session_token(user, device_info)
    Repo.insert!(user_token)
    token
  end

  @spec get_user_from_session_token(String.t()) :: User.t() | nil
  def get_user_from_session_token(token) do
    {:ok, query} = SessionToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @spec revoke_session_token(String.t()) :: :ok
  def revoke_session_token(token) do
    Repo.delete_all(SessionToken.by_token_query(token))
    :ok
  end

  @spec send_reset_password_instructions(User.t(), (String.t() -> String.t())) ::
          {:ok, map()} | {:error, any()}
  def send_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = EmailToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)

    UserNotifications.deliver_reset_password_instructions(
      user,
      reset_password_url_fun.(encoded_token)
    )
  end

  @spec get_user_from_reset_token(String.t()) :: User.t() | nil
  def get_user_from_reset_token(token) do
    with {:ok, query} <- EmailToken.get_verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @spec reset_user_password(User.t(), map()) :: user_operation_result()
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:session_tokens, SessionToken.by_user_query(user))
    |> Ecto.Multi.delete_all(:tokens, EmailToken.get_user_tokens_by_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @spec list_user_sessions(User.t(), String.t()) :: [map()]
  def list_user_sessions(user, current_token) do
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

  @spec revoke_other_user_sessions(User.t(), String.t()) :: {integer(), nil | [term()]}
  def revoke_other_user_sessions(user, current_token) do
    SessionToken.by_user_query(user)
    |> where([st], st.token != ^current_token)
    |> Repo.delete_all()
  end
end
