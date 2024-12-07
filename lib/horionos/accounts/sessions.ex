defmodule Horionos.Accounts.Sessions do
  @moduledoc """
  Session module
  """
  import Ecto.Query

  alias Horionos.Accounts.Schemas.SessionToken
  alias Horionos.Repo

  @doc """
  Creates a new session token for a user.

  ## Parameters
    - user: User struct
    - device_info: Optional map with device details

  ## Returns
    - Encoded session token
  """
  def create_session(user, device_info \\ nil) do
    {token, session_token_changeset} = SessionToken.create_session(user, device_info)
    Repo.insert!(session_token_changeset)
    token
  end

  @doc """
  Validates a session token and retrieves the associated user.

  ## Parameters
    - token: Session token string

  ## Returns
    - User struct or nil
  """
  def get_session_user(token) do
    days = SessionToken.days_for_session_validity()

    SessionToken
    |> where([st], st.token == ^token)
    |> join(:inner, [st], u in assoc(st, :user))
    |> where([st], st.inserted_at > ago(^days, "day"))
    |> select([st, u], u)
    |> Repo.one()
  end

  @doc """
  Revokes a specific session token.

  ## Parameters
    - token: Session token to revoke

  ## Returns
    - :ok
  """
  def revoke_session(token) do
    Repo.delete_all(from st in SessionToken, where: st.token == ^token)
    :ok
  end

  @doc """
  Revokes all session tokens for a user except the current one.

  ## Parameters
    - user: User struct
    - current_token: Token to keep active

  ## Returns
    - {number_of_revoked_sessions, nil}
  """
  def revoke_other_sessions(user, current_token) do
    Repo.delete_all(
      from st in SessionToken,
        where: st.user_id == ^user.id and st.token != ^current_token
    )
  end

  @doc """
  Lists all active sessions for a user.

  ## Parameters
    - user: User struct
    - current_token: Current active session token

  ## Returns
    - List of session details
  """
  def list_sessions(user, current_token) do
    SessionToken
    |> where(user_id: ^user.id)
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
end
