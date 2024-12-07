defmodule Horionos.Accounts.PasswordReset do
  @moduledoc """
  Manages password reset workflows.
  """

  alias Horionos.Accounts.Notifications.Dispatcher
  alias Horionos.Accounts.Schemas.User
  alias Horionos.Accounts.Tokens
  alias Horionos.Repo

  @doc """
  Initiates the password reset process.

  ## Parameters
    - user: User struct
    - reset_url_generator: Function that generates the reset URL

  ## Returns
    - {:ok, map()}
  """
  @spec initiate_reset(User.t(), (String.t() -> String.t())) :: {:ok, map()}
  def initiate_reset(user, reset_url_generator) do
    {encoded_token, token_changeset} = Tokens.create_token(user, "reset_password")
    Repo.insert!(token_changeset)

    Dispatcher.notify(:reset_password_instructions, %{
      user: user,
      url: reset_url_generator.(encoded_token)
    })
  end

  @doc """
  Validates a password reset token.

  ## Parameters
    - token: Token string

  ## Returns
    - User struct or nil
  """
  @spec validate_reset_token(String.t()) :: User.t() | nil
  def validate_reset_token(token) do
    case Tokens.verify_token(token, "reset_password") do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  @doc """
  Resets a user's password.

  ## Parameters
    - user: User struct
    - attrs: Map containing new password
    - opts: Keyword list of options
      - hash_password: Boolean, whether to hash the password

  ## Returns
    - {:ok, user}
    - {:error, changeset}
  """
  @spec reset_password(User.t(), map(), Keyword.t()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def reset_password(user, attrs, opts \\ []) do
    opts = Keyword.merge([hash_password: true], opts)

    # Change return type to be consistent
    case user
         |> User.password_changeset(attrs, opts)
         |> Repo.update() do
      {:ok, updated_user} = result ->
        Tokens.invalidate_user_tokens(updated_user)
        result

      error ->
        error
    end
  end
end
