defmodule Horionos.Orgs.InvitationManagement do
  @moduledoc """
  This module provides functions for managing invitations.
  """
  import Ecto.Query

  alias Horionos.Accounts
  alias Horionos.Accounts.User
  alias Horionos.Orgs.{Invitation, Membership, MembershipRole, Org}
  alias Horionos.Orgs.MembershipManagement
  alias Horionos.Repo
  alias Horionos.UserNotifications

  @doc """
  Creates an invitation for a user to join an organization.
  """
  @spec create_invitation(User.t(), Org.t(), String.t(), MembershipRole.t()) ::
          {:ok, Invitation.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :already_member}
          | {:error, :invalid_role}
  def create_invitation(inviter, org, email, role) do
    cond do
      MembershipManagement.user_in_org?(org, email) ->
        {:error, :already_member}

      role not in MembershipRole.assignable() ->
        {:error, :invalid_role}

      true ->
        %Invitation{}
        |> Invitation.changeset(%{
          email: email,
          token: Invitation.generate_token(),
          role: role,
          inviter_id: inviter.id,
          org_id: org.id
        })
        |> Repo.insert()
    end
  end

  @doc """
  Gets a pending invitation by its token.
  """
  @spec get_pending_invitation_by_token(String.t()) :: Invitation.t() | nil
  def get_pending_invitation_by_token(token) do
    Invitation
    |> where([i], i.token == ^token)
    |> where([i], is_nil(i.accepted_at))
    |> preload([:org, :inviter])
    |> Repo.one()
  end

  @doc """
  Accepts an invitation for a user. Creates a new user if needed.
  """
  @spec accept_invitation(Invitation.t(), map()) ::
          {:ok, %{user: User.t(), invitation: Invitation.t(), membership: Membership.t()}}
          | {:error, :already_accepted}
          | {:error, Ecto.Multi.name(), any(), %{required(Ecto.Multi.name()) => any()}}
  def accept_invitation(invitation, user_params) do
    if is_nil(invitation.accepted_at) do
      Ecto.Multi.new()
      |> Ecto.Multi.run(:user, fn _repo, _changes ->
        get_or_create_user(invitation.email, user_params)
      end)
      |> Ecto.Multi.update(:invitation, fn %{user: _user} ->
        Invitation.changeset(invitation, %{accepted_at: DateTime.utc_now()})
      end)
      |> Ecto.Multi.run(:membership, fn _repo, %{user: user} ->
        MembershipManagement.create_membership(%{
          user_id: user.id,
          org_id: invitation.org_id,
          role: invitation.role
        })
      end)
      |> Repo.transaction()
    else
      {:error, :already_accepted}
    end
  end

  @doc """
  Sends an invitation email.
  """
  @spec send_invitation_email(Invitation.t(), (String.t() -> String.t())) ::
          {:ok, Invitation.t()} | {:error, any()}
  def send_invitation_email(%Invitation{} = invitation, url_fn) do
    invitation = Repo.preload(invitation, [:inviter, :org])
    UserNotifications.deliver_invitation(invitation, url_fn.(invitation.token))
    {:ok, invitation}
  end

  @doc """
  Lists invitations for a given org.
  """
  @spec list_org_invitations(Org.t()) :: {:ok, [Invitation.t()]}
  def list_org_invitations(%Org{id: org_id}) do
    invitations =
      Invitation
      |> where([i], i.org_id == ^org_id)
      |> preload([:inviter])
      |> Repo.all()

    {:ok, invitations}
  end

  @doc """
  Builds an invitation changeset.
  """
  @spec build_invitation_changeset(Invitation.t(), map()) :: Ecto.Changeset.t()
  def build_invitation_changeset(invitation, attrs \\ %{}) do
    Invitation.changeset(invitation, attrs)
  end

  @doc """
  Delete an invitation.
  """
  @spec delete_invitation(integer()) ::
          {:ok, Invitation.t()} | {:error, Ecto.Changeset.t()} | {:error, :not_found}
  def delete_invitation(invitation_id) do
    case Repo.get(Invitation, invitation_id) do
      nil -> {:error, :not_found}
      invitation -> Repo.delete(invitation)
    end
  end

  # Private functions

  @spec get_or_create_user(String.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  defp get_or_create_user(email, user_params) do
    email
    |> Accounts.get_user_by_email()
    |> case do
      nil -> create_user(email, user_params)
      user -> {:ok, user}
    end
  end

  @spec create_user(String.t(), map()) ::
          {:ok, User.t()} | {:error, {:user_creation_failed, map()}}
  defp create_user(email, user_params) do
    user_params
    |> Map.put(:email, email)
    |> normalize_params()
    |> Accounts.register_user()
    |> case do
      {:ok, user} -> {:ok, user}
      {:error, changeset} -> handle_user_creation_error(changeset)
    end
  end

  @spec handle_user_creation_error(Ecto.Changeset.t()) :: {:error, {:user_creation_failed, map()}}
  defp handle_user_creation_error(changeset) do
    error_details = format_changeset_errors(changeset)
    {:error, {:user_creation_failed, error_details}}
  end

  @spec format_changeset_errors(Ecto.Changeset.t()) :: map()
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  @spec normalize_params(map()) :: map()
  defp normalize_params(params) do
    params
    |> Enum.map(fn {k, v} -> {to_string(k), v} end)
    |> Enum.into(%{})
  end
end
