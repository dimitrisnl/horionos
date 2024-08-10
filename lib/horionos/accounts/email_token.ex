defmodule Horionos.Accounts.EmailToken do
  @moduledoc """
  Manages the creation and verification of tokens for email-related operations.

  This module handles:
  - Generation of secure tokens for email verification, password resets, etc.
  - Verification of tokens for various email-related contexts
  - Database interactions for storing and retrieving email tokens

  It plays a crucial role in securing email-based workflows such as account
  confirmation and password resets, ensuring that these operations are
  both secure and time-limited.
  """

  use Ecto.Schema
  import Ecto.Query

  alias Horionos.Accounts.EmailToken
  alias Horionos.Accounts.User

  @hash_algorithm :sha256
  @rand_size 32
  @reset_password_validity_in_days Application.compile_env(
                                     :horionos,
                                     :reset_password_validity_in_days
                                   )
  @confirm_validity_in_days Application.compile_env(:horionos, :confirm_validity_in_days)
  @change_email_validity_in_days Application.compile_env(
                                   :horionos,
                                   :change_email_validity_in_days
                                 )

  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          token: binary(),
          context: String.t(),
          sent_to: String.t() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          user_id: integer() | nil,
          inserted_at: NaiveDateTime.t() | nil
        }

  schema "email_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    belongs_to :user, User

    timestamps(updated_at: false)
  end

  @doc """
  Builds a token and its hash to be delivered to the user's email.

  The non-hashed token is sent to the user email while the
  hashed part is stored in the database. The original token cannot be reconstructed,
  which means anyone with read-only access to the database cannot directly use
  the token in the application to gain access. Furthermore, if the user changes
  their email in the system, the tokens sent to the previous email are no longer
  valid.

  Users can easily adapt the existing code to provide other types of delivery methods,
  for example, by phone numbers.
  """
  @spec build_email_token(User.t(), String.t()) :: {binary(), t()}
  #
  def build_email_token(user, context) do
    build_hashed_token(user, context, user.email)
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user found by the token, if any.

  The given token is valid if it matches its hashed counterpart in the
  database and the user email has not changed. This function also checks
  if the token is being used within a certain period, depending on the
  context. The default contexts supported by this function are either
  "confirm", for account confirmation emails, and "reset_password",
  for resetting the password. For verifying requests to change the email,
  see `get_verify_change_email_token_query/2`.
  """
  @spec get_verify_email_token_query(binary(), String.t()) :: {:ok, Ecto.Query.t()} | :error
  #
  def get_verify_email_token_query(token, context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)
        days = days_for_context(context)

        query =
          from token in get_token_and_context_query(hashed_token, context),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(^days, "day") and token.sent_to == user.email,
            select: user

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user found by the token, if any.

  This is used to validate requests to change the user
  email. It is different from `get_verify_email_token_query/2` precisely because
  `get_verify_email_token_query/2` validates the email has not changed, which is
  the starting point by this function.

  The given token is valid if it matches its hashed counterpart in the
  database and if it has not expired (after @change_email_validity_in_days).
  The context must always start with "change:".
  """
  @spec get_verify_change_email_token_query(binary(), String.t()) :: {:ok, Ecto.Query.t()} | :error
  #
  def get_verify_change_email_token_query(token, "change:" <> _ = context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in get_token_and_context_query(hashed_token, context),
            where: token.inserted_at > ago(@change_email_validity_in_days, "day")

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Returns the token struct for the given token value and context.
  """
  @spec get_token_and_context_query(binary(), String.t()) :: Ecto.Query.t()
  #
  def get_token_and_context_query(token, context) do
    from EmailToken, where: [token: ^token, context: ^context]
  end

  @doc """
  Gets all tokens for the given user for the given contexts.
  """
  @spec get_user_tokens_by_contexts_query(User.t(), :all | [String.t()]) :: Ecto.Query.t()
  #
  def get_user_tokens_by_contexts_query(user, :all) do
    from t in EmailToken, where: t.user_id == ^user.id
  end

  @spec get_user_tokens_by_contexts_query(User.t(), [String.t()]) :: Ecto.Query.t()
  #
  def get_user_tokens_by_contexts_query(user, [_ | _] = contexts) do
    from t in EmailToken, where: t.user_id == ^user.id and t.context in ^contexts
  end

  defp build_hashed_token(user, context, sent_to) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %EmailToken{
       token: hashed_token,
       context: context,
       sent_to: sent_to,
       user_id: user.id
     }}
  end

  defp days_for_context("confirm"), do: @confirm_validity_in_days
  defp days_for_context("reset_password"), do: @reset_password_validity_in_days
end
