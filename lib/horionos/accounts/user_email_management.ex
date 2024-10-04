defmodule Horionos.Accounts.UserEmailManagement do
  @moduledoc """
  Handles all email-related operations for user accounts.

  This module is responsible for:
  - Managing email change processes
  - Sending various email notifications (e.g., confirmation, password reset)
  - Verifying email addresses
  - Checking email verification statuses

  It provides functions to initiate and complete email-related workflows,
  ensuring that user email addresses are properly verified and updated
  within the system.
  """

  alias Horionos.Accounts.EmailToken
  alias Horionos.Accounts.User
  alias Horionos.Repo
  alias Horionos.UserNotifications

  @unconfirmed_email_deadline_in_days Application.compile_env(
                                        :horionos,
                                        :unconfirmed_email_deadline_in_days
                                      )

  @spec build_email_changeset(User.t(), map()) :: Ecto.Changeset.t()
  def build_email_changeset(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @spec apply_email_change(User.t(), String.t(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def apply_email_change(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @spec update_user_email(User.t(), String.t()) :: :ok | :error
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- EmailToken.get_verify_change_email_token_query(token, context),
         %EmailToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  @spec send_update_email_instructions(User.t(), String.t(), (String.t() -> String.t())) ::
          {:ok, map()} | {:error, any()}
  def send_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = EmailToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)

    UserNotifications.deliver_update_email_instructions(
      user,
      update_email_url_fun.(encoded_token)
    )
  end

  @spec send_confirmation_instructions(User.t(), (String.t() -> String.t())) ::
          {:ok, map()} | {:error, :already_confirmed}
  def send_confirmation_instructions(%User{} = user, confirmation_url_fun)
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

  @spec confirm_user_email(String.t()) :: {:ok, User.t()} | :error
  def confirm_user_email(token) do
    with {:ok, query} <- EmailToken.get_verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_email_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  @spec email_verified?(User.t()) :: boolean()
  def email_verified?(user) do
    !is_nil(user.confirmed_at)
  end

  @spec get_email_verification_deadline(User.t()) :: DateTime.t()
  def get_email_verification_deadline(%User{} = user) do
    DateTime.add(user.inserted_at, @unconfirmed_email_deadline_in_days, :day)
  end

  @spec email_verification_pending?(User.t()) :: boolean()
  def email_verification_pending?(user) do
    now = truncate_datetime(DateTime.utc_now())

    is_nil(user.confirmed_at) &&
      DateTime.compare(get_email_verification_deadline(user), now) == :gt
  end

  @spec email_verified_or_pending?(User.t()) :: boolean()
  def email_verified_or_pending?(user) do
    email_verified?(user) || email_verification_pending?(user)
  end

  # Private functions

  @spec user_email_multi(User.t(), String.t(), String.t()) :: Ecto.Multi.t()
  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(
      :tokens,
      EmailToken.get_user_tokens_by_contexts_query(user, [context])
    )
  end

  @spec confirm_user_email_multi(User.t()) :: Ecto.Multi.t()
  defp confirm_user_email_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(
      :tokens,
      EmailToken.get_user_tokens_by_contexts_query(user, ["confirm"])
    )
  end

  @spec truncate_datetime(DateTime.t()) :: DateTime.t()
  defp truncate_datetime(datetime) do
    DateTime.truncate(datetime, :second)
  end
end
