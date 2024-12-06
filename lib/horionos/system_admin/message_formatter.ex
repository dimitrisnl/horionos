defmodule Horionos.SystemAdmin.MessageFormatter do
  @moduledoc """
  Module to format Slack notifications.
  """

  # User events
  def format(:successful_login, %{email: email}) do
    "🔑 Successful login: #{email}"
  end

  def format(:failed_login_attempt, %{email: email}) do
    "⁉️ Failed login: #{email}"
  end

  def format(:failed_login_without_verification, %{email: email}) do
    "🔒 Failed login without verification: #{email}"
  end

  def format(:failed_login_rate_limit_exceeded, %{email: email}) do
    "🚫 Rate limit exceeded: #{email}"
  end

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
        membership: membership
      }) do
    "👥 User joined organization: #{user.full_name} (#{user.email}) joined organization #{membership.organization.title} as #{membership.role}, invited by #{membership.user.full_name} (#{membership.user.email})"
  end

  def format(:organization_deleted, %{organization: organization}) do
    "🗑 Organization deleted: #{organization.title}"
  end

  # Authorization errors
  def format(:authorization_error, %{
        user: user,
        resource: resource,
        permission: permission
      }) do
    "⚠️ Authorization error: #{user.full_name} (#{user.email}) tried action `#{permission}` on resource with id #{resource.id}"
  end

  # Cron jobs
  def format(:cron_job_started, %{job: job}) do
    "🕒 Cron job started: #{job.name}"
  end

  def format(:cron_job_succeeded, %{job: job}) do
    "✅ Cron job succeeded: '#{job.name}', #{job.details}"
  end

  def format(:cron_job_failed, %{job: job}) do
    "🚨 Cron job failed: #{job.name}"
  end
end
