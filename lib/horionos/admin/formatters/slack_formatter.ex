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

  def format(:user_joined_organization, %{
        user: user,
        organization: organization,
        role: role,
        inviter: inviter
      }) do
    "👥 User joined organization: #{user.full_name} (#{user.email}) joined #{organization.title} as #{role}, invited by #{inviter.full_name} (#{inviter.email})"
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
