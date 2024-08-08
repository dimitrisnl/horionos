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
end
