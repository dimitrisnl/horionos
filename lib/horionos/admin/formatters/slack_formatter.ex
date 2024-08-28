defmodule Horionos.Admin.Formatters.SlackFormatter do
  @moduledoc """
  Module to format Slack notifications.
  """
  def format(:user_registered, %{full_name: full_name, email: email}) do
    "✨ New user registered: #{full_name} (#{email})"
  end

  def format(:user_locked, %{full_name: full_name, email: email}) do
    "🔒 User locked: #{full_name} (#{email})"
  end

  def format(:invitation_created, %{
        inviter: inviter,
        organization: organization,
        invitation: invitation
      }) do
    "💌 Invitation created: #{inviter.full_name} (#{inviter.email}) invited #{invitation.email} to join #{organization.title} as #{invitation.role}"
  end

  def format(:user_joined_organization, %{
        user: user,
        invitation: invitation,
        membership: membership
      }) do
    "👥 User joined organization: #{user.full_name} (#{user.email}) joined organization #{membership.organization_id} as #{membership.role}, invited by #{invitation.inviter_id}"
  end

  def format(:organization_deleted, %{organization: organization}) do
    "🗑 Organization deleted: #{organization.title}"
  end

  def format(:authorization_error, %{
        user: user,
        resource: resource,
        permission: permission,
        error: error
      }) do
    "⚠️ Authorization error: #{user.full_name} (#{user.email}) tried to '#{permission}' on #{inspect(resource)} but failed with error: #{inspect(error)}"
  end
end
