defmodule Horionos.Accounts.Tokens do
  @moduledoc """
  Tokens module for user account management.
  """

  import Ecto.Query

  alias Horionos.Accounts.Schemas.EmailToken
  alias Horionos.Accounts.Schemas.SessionToken
  alias Horionos.Accounts.Schemas.User
  alias Horionos.Constants
  alias Horionos.Repo

  @reset_password_validity_in_days Constants.reset_password_validity_in_days()
  @confirm_validity_in_days Constants.confirm_validity_in_days()
  @change_email_validity_in_days Constants.change_email_validity_in_days()

  def days_for_context("confirm"), do: @confirm_validity_in_days
  def days_for_context("reset_password"), do: @reset_password_validity_in_days
  def days_for_context("change:" <> _), do: @change_email_validity_in_days

  @doc """
  Verify a token for a specific context.

  ## Parameters
    - token: Encoded token string
    - context: Context string (e.g., "confirm", "reset_password", "change:email@example.com")

  ## Returns
    - {:ok, user} if token is valid
    - {:error, :invalid_token} otherwise
  """
  @spec verify_token(String.t(), String.t()) :: {:ok, User.t()} | {:error, atom()}
  def verify_token(token, context) do
    case EmailToken.decode(token) do
      {:ok, decoded_token} ->
        hashed_token = EmailToken.hash(decoded_token)
        days = days_for_context(context)

        result =
          EmailToken
          |> where([t], t.token == ^hashed_token and t.context == ^context)
          |> where([t], t.inserted_at > ago(^days, "day"))
          |> join(:inner, [t], u in assoc(t, :user))
          |> select([t, u], u)
          |> Repo.one()

        case result do
          nil -> {:error, :invalid_token}
          user -> {:ok, user}
        end

      :error ->
        {:error, :invalid_token}
    end
  end

  @doc """
  Create a token for a specific context.

  ## Parameters
    - user: User struct
    - context: Context string

  ## Returns
    - {encoded_token, token_changeset}
  """
  @spec create_token(User.t(), String.t()) :: {String.t(), Ecto.Changeset.t()}
  def create_token(user, context) do
    EmailToken.create_email_token(user, context)
  end

  @doc """
  Invalidate all tokens for a specific user.

  ## Parameters
    - user: User struct

  ## Returns
    - :ok on successful invalidation
  """
  @spec invalidate_user_tokens(User.t()) :: :ok
  def invalidate_user_tokens(user) do
    Repo.transaction(fn ->
      Repo.delete_all(from st in SessionToken, where: st.user_id == ^user.id)
      Repo.delete_all(from et in EmailToken, where: et.user_id == ^user.id)
    end)

    :ok
  end

  @doc """
  Invalidate tokens for a specific context.

  ## Parameters
    - user: User struct
    - context: Token context string to invalidate

  ## Returns
    - Number of tokens deleted
  """
  @spec invalidate_tokens_by_context(User.t(), String.t()) :: integer()
  def invalidate_tokens_by_context(user, context) do
    {count, _} =
      Repo.delete_all(
        from et in EmailToken,
          where: et.user_id == ^user.id and et.context == ^context
      )

    count
  end
end
