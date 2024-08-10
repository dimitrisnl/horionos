defmodule Horionos.Accounts.SessionToken do
  @moduledoc """
  Handles the creation and management of session tokens for user authentication.

  Key functionalities include:
  - Generating secure session tokens
  - Storing and retrieving session information
  - Validating session tokens
  - Managing token expiration

  This module is essential for maintaining user sessions securely,
  allowing for features like "remember me" functionality and
  multi-device session management.
  """

  use Ecto.Schema
  import Ecto.Query

  alias Horionos.Accounts.SessionToken
  alias Horionos.Accounts.User

  @rand_size 32
  @session_validity_in_days Application.compile_env(:horionos, :session_validity_in_days)

  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          token: binary(),
          user: User.t() | Ecto.Association.NotLoaded.t(),
          user_id: integer() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          device: String.t(),
          os: String.t(),
          browser: String.t(),
          browser_version: String.t()
        }

  schema "session_tokens" do
    field :token, :binary
    field :device, :string
    field :os, :string
    field :browser, :string
    field :browser_version

    belongs_to :user, User

    timestamps(updated_at: false)
  end

  @doc """
  Generates a token that will be stored in a signed place,
  such as session or cookie. As they are signed, those
  tokens do not need to be hashed.

  The reason why we store session tokens in the database, even
  though Phoenix already provides a session cookie, is because
  Phoenix' default session cookies are not persisted, they are
  simply signed and potentially encrypted. This means they are
  valid indefinitely, unless you change the signing/encryption
  salt.

  Therefore, storing them allows individual user
  sessions to be expired. The token system can also be extended
  to store additional data, such as the device used for logging in.
  You could then use this information to display all valid sessions
  and devices in the UI and allow users to explicitly expire any
  session they deem invalid.
  """
  @spec build_session_token(User.t(), map() | nil) :: {binary(), t()}
  #
  def build_session_token(user, device_info \\ nil) do
    token = :crypto.strong_rand_bytes(@rand_size)

    session_token = %SessionToken{
      token: token,
      user_id: user.id
    }

    session_token =
      if device_info do
        %{
          session_token
          | device: Map.get(device_info, :device, "Unknown"),
            os: Map.get(device_info, :os, "Unknown"),
            browser: Map.get(device_info, :browser, "Unknown"),
            browser_version: Map.get(device_info, :browser_version, "")
        }
      else
        session_token
      end

    {token, session_token}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user found by the token, if any.

  The token is valid if it matches the value in the database and it has
  not expired (after @session_validity_in_days).
  """
  @spec verify_session_token_query(binary()) :: {:ok, Ecto.Query.t()}
  #
  def verify_session_token_query(token) do
    query =
      from token in by_token_query(token),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: user

    {:ok, query}
  end

  @doc """
  Returns the token struct for the given token value and context.
  """
  @spec by_token_query(binary()) :: Ecto.Query.t()
  #
  def by_token_query(token) do
    from SessionToken, where: [token: ^token]
  end

  @doc """
  Gets all tokens for the given user for the given contexts.
  """
  @spec by_user_query(User.t()) :: Ecto.Query.t()
  #
  def by_user_query(user) do
    from t in SessionToken, where: t.user_id == ^user.id
  end
end
