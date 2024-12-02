defmodule Horionos.Invitations.Invitations do
  @moduledoc """
  This module provides functions for managing invitations.
  """
  import Ecto.Query

  alias Horionos.Accounts.Notifications.Dispatcher
  alias Horionos.Accounts.Schemas.User
  alias Horionos.Accounts.Users
  alias Horionos.Invitations.Helpers.InvitationToken
  alias Horionos.Invitations.Schemas.Invitation
  alias Horionos.Memberships.Helpers.MembershipRole
  alias Horionos.Memberships.Memberships
  alias Horionos.Memberships.Schemas.Membership
  alias Horionos.Organizations.Schemas.Organization
  alias Horionos.Repo
  alias Horionos.SystemAdmin.Notifier, as: SystemAdminNotifications

  # Todo: redo this
  @spec create_invitation(User.t(), Organization.t(), String.t(), MembershipRole.t()) ::
          {:ok, %{invitation: Invitation.t(), token: String.t()}}
          | {:error, Ecto.Changeset.t()}
          | {:error, :already_member}
          | {:error, :invalid_role}
  def create_invitation(inviter, organization, email, role) do
    cond do
      # Not exhaustive authorization check, just a double check to prevent any mistakes
      not Memberships.user_in_organization?(organization, inviter.email) ->
        {:error, :unauthorized}

      Memberships.user_in_organization?(organization, email) ->
        {:error, :already_member}

      role not in MembershipRole.assignable() ->
        {:error, :invalid_role}

      true ->
        {token, invitation_attrs} =
          InvitationToken.generate(inviter, organization, email, role)

        changeset = Invitation.create_changeset(invitation_attrs)

        case Repo.insert(changeset) do
          {:ok, saved_invitation} ->
            notify_invitation_created(inviter, organization, saved_invitation)
            {:ok, %{invitation: saved_invitation, token: token}}

          error ->
            error
        end
    end
  end

  @spec get_pending_invitation_by_token(String.t()) ::
          {:ok, Invitation.t()} | {:error, :invalid_token}
  def get_pending_invitation_by_token(token) do
    case InvitationToken.decode(token) do
      :error ->
        {:error, :invalid_token}

      {:ok, decoded_token} ->
        hashed_token = InvitationToken.hash(decoded_token)
        now = DateTime.utc_now()

        invitation =
          Invitation
          |> where([i], i.token == ^hashed_token)
          |> where([i], i.expires_at > ^now)
          |> where([i], is_nil(i.accepted_at))
          |> preload([:organization, :inviter])
          |> Repo.one()

        case invitation do
          nil -> {:error, :invalid_token}
          _invitation -> {:ok, invitation}
        end
    end
  end

  @doc """
  Accepts an invitation for a user. Creates a new user if needed.
  """
  @spec accept_invitation(Invitation.t(), map()) ::
          {:ok, %{user: User.t(), invitation: Invitation.t(), membership: Membership.t()}}
          | {:error, :already_accepted}
          | {:error, :expired}
          | {:error, Ecto.Multi.name(), any(), %{required(Ecto.Multi.name()) => any()}}
  def accept_invitation(invitation, user_params) do
    cond do
      not is_nil(invitation.accepted_at) ->
        {:error, :already_accepted}

      Invitation.expired?(invitation) ->
        {:error, :expired}

      true ->
        result = do_accept_invitation(invitation, user_params)

        case result do
          {:ok, data} ->
            notify_user_joined(data)
            {:ok, data}

          error ->
            error
        end
    end
  end

  defp do_accept_invitation(invitation, user_params) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:user, fn repo, _changes ->
      with {:ok, user} <- get_or_create_user(invitation.email, user_params),
           {:ok, updated_user} <-
             user
             |> User.confirm_changeset()
             |> repo.update() do
        {:ok, updated_user}
      else
        {:error, reason} -> {:error, reason}
      end
    end)
    |> Ecto.Multi.update(:invitation, fn _ ->
      Invitation.accept_changeset(invitation, %{accepted_at: DateTime.utc_now()})
    end)
    |> Ecto.Multi.run(:membership, fn _repo, %{user: user} ->
      Memberships.create_membership(%{
        user_id: user.id,
        organization_id: invitation.organization_id,
        role: invitation.role
      })
    end)
    |> Repo.transaction()
  end

  defp notify_user_joined(%{user: user, membership: membership}) do
    membership_with_assocs = Repo.preload(membership, [:organization, :user])

    SystemAdminNotifications.notify(:user_joined_organization, %{
      user: user,
      membership: membership_with_assocs
    })
  end

  @spec send_invitation_email(Invitation.t(), String.t()) ::
          {:ok, Invitation.t()} | {:error, any()}
  def send_invitation_email(%Invitation{} = invitation, invitation_url) do
    invitation = Repo.preload(invitation, [:inviter, :organization])

    Dispatcher.notify(:new_invitation, %{
      inviter: invitation.inviter,
      email: invitation.email,
      url: invitation_url,
      organization: invitation.organization
    })

    {:ok, invitation}
  end

  @spec list_pending_organization_invitations(Organization.t()) :: {:ok, [Invitation.t()]}
  def list_pending_organization_invitations(%Organization{id: organization_id}) do
    invitations =
      Invitation
      |> where([i], i.organization_id == ^organization_id)
      |> where([i], is_nil(i.accepted_at))
      |> where([i], i.expires_at > ^DateTime.utc_now())
      |> preload([:inviter])
      |> Repo.all()

    {:ok, invitations}
  end

  @spec build_invitation_changeset(map()) :: Ecto.Changeset.t()
  def build_invitation_changeset(attrs) do
    Invitation.create_changeset(attrs)
  end

  @spec delete_invitation(integer()) ::
          {:ok, Invitation.t()} | {:error, Ecto.Changeset.t()} | {:error, :not_found}
  def delete_invitation(invitation_id) do
    case Repo.get(Invitation, invitation_id) do
      nil -> {:error, :not_found}
      invitation -> Repo.delete(invitation)
    end
  end

  @spec delete_expired_invitations() :: {non_neg_integer(), nil | [term()]}
  def delete_expired_invitations do
    Invitation
    |> where([i], i.expires_at <= ^DateTime.utc_now())
    |> where([i], is_nil(i.accepted_at))
    |> Repo.delete_all()
  end

  @spec get_or_create_user(String.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  defp get_or_create_user(email, user_params) do
    email
    |> Users.get_user_by_email()
    |> case do
      nil -> create_user(email, user_params)
      user -> {:ok, user}
    end
  end

  @spec create_user(String.t(), map()) ::
          {:ok, User.t()} | {:error, {:user_creation_failed, map()}}
  defp create_user(email, user_params) do
    user_params
    |> normalize_params()
    # override email with the one from the invitation
    # to ensure the user is created with the correct email
    # We don't allow this in the UI, but you never know
    |> Map.put("email", email)
    |> Users.register_user()
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

  def notify_invitation_created(inviter, organization, invitation) do
    SystemAdminNotifications.notify(:invitation_created, %{
      inviter: inviter,
      organization: organization,
      invitation: invitation
    })
  end
end
