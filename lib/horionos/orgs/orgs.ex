defmodule Horionos.Orgs do
  @moduledoc """
  The Orgs context serves as a facade for all organization-related operations.

  This module provides a simplified interface to the complex subsystem of
  organization management, membership management, and invitation management.
  """

  alias Horionos.Orgs.{
    InvitationManagement,
    MembershipManagement,
    OrganizationManagement
  }

  # Organization management
  defdelegate create_org(user, attrs), to: OrganizationManagement
  defdelegate update_org(org, attrs), to: OrganizationManagement
  defdelegate delete_org(org), to: OrganizationManagement
  defdelegate list_user_orgs(user), to: OrganizationManagement
  defdelegate get_user_primary_org(user), to: OrganizationManagement
  defdelegate build_org_changeset(org, attrs \\ %{}), to: OrganizationManagement
  defdelegate get_org(org_id), to: OrganizationManagement

  # Membership management
  defdelegate list_org_memberships(org), to: MembershipManagement
  defdelegate update_membership(membership, attrs), to: MembershipManagement
  defdelegate delete_membership(membership), to: MembershipManagement
  defdelegate create_membership(attrs), to: MembershipManagement

  # Invitation management
  defdelegate list_org_invitations(org), to: InvitationManagement
  defdelegate accept_invitation(invitation, user_params), to: InvitationManagement
  defdelegate get_pending_invitation_by_token(token), to: InvitationManagement
  defdelegate delete_invitation(invitation_id), to: InvitationManagement
  defdelegate send_invitation_email(invitation, url_fn), to: InvitationManagement
  defdelegate build_invitation_changeset(invitation, attrs \\ %{}), to: InvitationManagement
  defdelegate create_invitation(inviter, org, email, role), to: InvitationManagement

  # Helpers
  defdelegate user_in_org?(org, email), to: MembershipManagement
  defdelegate user_has_any_membership?(email), to: MembershipManagement
  defdelegate get_user_role(user, org), to: MembershipManagement
end
