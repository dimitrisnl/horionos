defmodule Horionos.Orgs do
  @moduledoc """
  The Orgs context serves as a facade for all organization-related operations.

  This module provides a simplified interface to the complex subsystem of
  organization management, membership management, invitation management,
  and authorization.
  """

  alias Horionos.Accounts.User
  alias Horionos.Orgs.{Invitation, Membership, MembershipRole, Org}
  alias Horionos.Authorization

  alias Horionos.Orgs.{
    InvitationManagement,
    MembershipManagement,
    OrganizationManagement
  }

  # Organization management

  @spec create_org(User.t(), map()) :: {:ok, Org.t()} | {:error, Ecto.Changeset.t()}
  def create_org(user, attrs) do
    OrganizationManagement.create_org(user, attrs)
  end

  @spec update_org(User.t(), Org.t(), map()) ::
          {:ok, Org.t()} | {:error, Ecto.Changeset.t()} | {:error, Authorization.error()}
  def update_org(user, org, attrs) do
    Authorization.with_authorization(user, org, :org_edit, fn ->
      OrganizationManagement.update_org(org, attrs)
    end)
  end

  @spec delete_org(User.t(), Org.t()) ::
          {:ok, Org.t()} | {:error, Authorization.error()} | {:error, any()}
  def delete_org(user, org) do
    Authorization.with_authorization(user, org, :org_delete, fn ->
      OrganizationManagement.delete_org(org)
    end)
  end

  @spec list_user_orgs(User.t()) :: [Org.t()]
  def list_user_orgs(user) do
    OrganizationManagement.list_user_orgs(user)
  end

  @spec get_org(User.t(), integer() | String.t()) ::
          {:ok, Org.t()} | {:error, :unauthorized} | {:error, :invalid_org_id}
  def get_org(user, org_id) when is_binary(org_id) do
    case Integer.parse(org_id) do
      {id, ""} -> get_org(user, id)
      _ -> {:error, :invalid_org_id}
    end
  end

  def get_org(user, org_id) when is_integer(org_id) do
    case OrganizationManagement.get_org(user, org_id) do
      {:ok, org} ->
        case Authorization.authorize(user, org, :org_view) do
          :ok -> {:ok, org}
          error -> error
        end

      error ->
        error
    end
  end

  @spec get_user_primary_org(User.t()) :: Org.t() | nil
  def get_user_primary_org(user) do
    OrganizationManagement.get_user_primary_org(user)
  end

  @spec build_org_changeset(Org.t(), map()) :: Ecto.Changeset.t()
  def build_org_changeset(org, attrs \\ %{}) do
    OrganizationManagement.build_org_changeset(org, attrs)
  end

  # Membership management

  @spec list_org_memberships(User.t(), Org.t()) ::
          {:ok, [Membership.t()]} | {:error, Authorization.error()}
  def list_org_memberships(user, org) do
    Authorization.with_authorization(user, org, :org_view, fn ->
      {:ok, MembershipManagement.list_org_memberships(org)}
    end)
  end

  @spec create_membership(User.t(), map()) ::
          {:ok, Membership.t()} | {:error, Ecto.Changeset.t() | :unauthorized | :invalid_role}
  def create_membership(creator, attrs) do
    with {:ok, org} <- get_org(creator, attrs.org_id),
         :ok <- Authorization.authorize(creator, org, :org_manage_members),
         true <- MembershipRole.valid?(attrs.role),
         true <- role_in_assignable?(attrs.role) do
      MembershipManagement.create_membership(attrs)
    else
      false -> {:error, :invalid_role}
      error -> error
    end
  end

  @spec update_membership(User.t(), Membership.t(), map()) ::
          {:ok, Membership.t()} | {:error, Ecto.Changeset.t()} | {:error, Authorization.error()}
  def update_membership(updater, membership, attrs) do
    with {:ok, org} <- get_org(updater, membership.org_id) do
      Authorization.with_authorization(updater, org, :org_manage_members, fn ->
        MembershipManagement.update_membership(membership, attrs)
      end)
    end
  end

  @spec delete_membership(User.t(), Membership.t()) ::
          {:ok, Membership.t()} | {:error, Ecto.Changeset.t()} | {:error, Authorization.error()}
  def delete_membership(deleter, membership) do
    with {:ok, org} <- get_org(deleter, membership.org_id) do
      Authorization.with_authorization(deleter, org, :org_manage_members, fn ->
        MembershipManagement.delete_membership(membership)
      end)
    end
  end

  # Invitation management

  @spec create_invitation(User.t(), Org.t(), String.t(), MembershipRole.t()) ::
          {:ok, Invitation.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, Authorization.error()}
          | {:error, :already_member}
  def create_invitation(inviter, org, email, role) do
    Authorization.with_authorization(inviter, org, :org_invite_members, fn ->
      if user_in_org?(org, email) do
        {:error, :already_member}
      else
        InvitationManagement.create_invitation(inviter, org, email, role)
      end
    end)
  end

  @spec list_org_invitations(User.t(), Org.t()) ::
          {:ok, [Invitation.t()]} | {:error, Authorization.error()}
  def list_org_invitations(user, org) do
    Authorization.with_authorization(user, org, :org_invite_members, fn ->
      {:ok, InvitationManagement.list_org_invitations(org)}
    end)
  end

  @spec accept_invitation(Invitation.t(), map()) ::
          {:ok, %{user: User.t(), invitation: Invitation.t(), membership: Membership.t()}}
          | {:error, :already_accepted}
          | {:error, Ecto.Multi.name(), any(), %{required(Ecto.Multi.name()) => any()}}
  def accept_invitation(invitation, user_params) do
    InvitationManagement.accept_invitation(invitation, user_params)
  end

  @spec get_pending_invitation_by_token(String.t()) :: Invitation.t() | nil
  def get_pending_invitation_by_token(token) do
    InvitationManagement.get_pending_invitation_by_token(token)
  end

  @spec cancel_invitation(User.t(), Org.t(), integer()) ::
          {:ok, Invitation.t()} | {:error, Authorization.error()} | {:error, :not_found}
  def cancel_invitation(canceller, org, invitation_id) do
    Authorization.with_authorization(canceller, org, :org_invite_members, fn ->
      InvitationManagement.cancel_invitation(invitation_id)
    end)
  end

  @spec send_invitation_email(Invitation.t(), (String.t() -> String.t())) ::
          {:ok, Invitation.t()} | {:error, any()}
  def send_invitation_email(invitation, url_fn) do
    InvitationManagement.send_invitation_email(invitation, url_fn)
  end

  @spec build_invitation_changeset(Invitation.t(), map()) :: Ecto.Changeset.t()
  def build_invitation_changeset(invitation, attrs \\ %{}) do
    InvitationManagement.build_invitation_changeset(invitation, attrs)
  end

  # Authorization helpers

  @spec user_in_org?(Org.t(), String.t()) :: boolean()
  def user_in_org?(org, email) do
    MembershipManagement.user_in_org?(org, email)
  end

  @spec user_has_any_membership?(String.t()) :: boolean()
  def user_has_any_membership?(email) do
    MembershipManagement.user_has_any_membership?(email)
  end

  @spec get_user_role(User.t(), Org.t()) :: {:ok, MembershipRole.t()} | {:error, :not_found}
  def get_user_role(user, org) do
    MembershipManagement.get_user_role(user.id, org.id)
  end

  @spec role_in_assignable?(MembershipRole.t()) :: boolean()
  defp role_in_assignable?(role) do
    role in MembershipRole.assignable()
  end
end
