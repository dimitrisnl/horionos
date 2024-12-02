defmodule Horionos.Accounts.EmailVerification do
  @moduledoc """
  Handles email verification and change workflows.
  """

  alias Horionos.Accounts.Notifications.Dispatcher
  alias Horionos.Accounts.Schemas.EmailToken
  alias Horionos.Accounts.Schemas.User
  alias Horionos.Accounts.Tokens
  alias Horionos.Repo

  @doc """
  Sends confirmation instructions to a user.
  """
  @spec send_confirmation_instructions(User.t(), (String.t() -> String.t())) ::
          {:ok, map()} | {:error, :already_confirmed}
  def send_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, token_changeset} = Tokens.create_token(user, "confirm")
      Repo.insert!(token_changeset)

      Dispatcher.notify(:confirm_email_instructions, %{
        user: user,
        url: confirmation_url_fun.(encoded_token)
      })
    end
  end

  @doc """
  Confirms a user's email address using a token.
  """
  @spec confirm_email(String.t()) :: {:ok, User.t()} | {:error, :invalid_token}
  def confirm_email(token) do
    with {:ok, user} <- Tokens.verify_token(token, "confirm"),
         {:ok, %{user: user}} <- Repo.transaction(confirm_email_multi(user)) do
      {:ok, user}
    else
      error -> error
    end
  end

  @doc """
  Initiates email change process.
  """
  def initiate_email_change(%User{} = user, new_email, update_email_url_fun) do
    {encoded_token, token_changeset} = Tokens.create_token(user, "change:#{user.email}")
    # Store the new_email we're changing to, not the current one
    token_changeset = Ecto.Changeset.put_change(token_changeset, :sent_to, new_email)
    Repo.insert!(token_changeset)

    Dispatcher.notify(:update_email_instructions, %{
      user: user,
      url: update_email_url_fun.(encoded_token)
    })
  end

  @doc """
  Completes the email change process.
  """
  def complete_email_change(user, token) do
    context = "change:#{user.email}"

    with {:ok, token_user} <- Tokens.verify_token(token, context),
         true <- token_user.id == user.id,
         token_record <- Repo.get_by(EmailToken, context: context, user_id: user.id),
         new_email = token_record.sent_to,
         {:ok, _} <- Repo.transaction(change_email_multi(user, new_email)) do
      :ok
    else
      _ -> :error
    end
  end

  defp confirm_email_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.run(:invalidate_tokens, fn _repo, %{user: user} ->
      count = Tokens.invalidate_tokens_by_context(user, "confirm")
      {:ok, count}
    end)
  end

  defp change_email_multi(user, new_email) do
    original_email = user.email

    changeset =
      user
      |> User.email_changeset(%{email: new_email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.run(:invalidate_tokens, fn _repo, %{user: _updated_user} ->
      count = Tokens.invalidate_tokens_by_context(user, "change:#{original_email}")
      {:ok, count}
    end)
  end
end
