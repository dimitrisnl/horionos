defmodule Horionos.Organizations do
  @moduledoc """
  The Organizations context serves as a facade for all organization-related operations.

  This module provides a simplified interface to the complex subsystem of
  organization management, membership management, and invitation management.
  """

  alias Horionos.Organizations.InvitationManagement
  alias Horionos.Organizations.MembershipManagement
  alias Horionos.Organizations.OrganizationManagement

  # Organization management
  defdelegate create_organization(user, attrs), to: OrganizationManagement
  defdelegate update_organization(organization, attrs), to: OrganizationManagement
  defdelegate delete_organization(organization), to: OrganizationManagement
  defdelegate get_user_primary_organization(user), to: OrganizationManagement
  defdelegate build_organization_changeset(organization, attrs \\ %{}), to: OrganizationManagement
  defdelegate get_organization(organization_id), to: OrganizationManagement

  # Membership management
  defdelegate list_user_memberships(user), to: MembershipManagement
  defdelegate list_organization_memberships(organization), to: MembershipManagement
  defdelegate update_membership(membership, attrs), to: MembershipManagement
  defdelegate delete_membership(membership), to: MembershipManagement
  defdelegate create_membership(attrs), to: MembershipManagement

  # Invitation management
  defdelegate list_pending_organization_invitations(organization), to: InvitationManagement
  defdelegate accept_invitation(invitation, user_params), to: InvitationManagement
  defdelegate get_pending_invitation_by_token(token), to: InvitationManagement
  defdelegate delete_invitation(invitation_id), to: InvitationManagement
  defdelegate delete_expired_invitations(), to: InvitationManagement
  defdelegate send_invitation_email(invitation, invitation_url), to: InvitationManagement
  defdelegate build_invitation_changeset(invitation, attrs \\ %{}), to: InvitationManagement
  defdelegate create_invitation(inviter, organization, email, role), to: InvitationManagement

  # Helpers
  defdelegate user_in_organization?(organization, email), to: MembershipManagement
  defdelegate user_has_any_membership?(email), to: MembershipManagement
  defdelegate get_user_role(user, organization), to: MembershipManagement
end
