defmodule Horionos.Notifications do
  @moduledoc """
  The Notifications context.
  Handles sending notifications to admins.
  """
  alias Horionos.Workers.SlackNotificationWorker

  require Logger

  def notify(event, details) do
    message = format_message(event, details)

    case Application.get_env(:horionos, :notification_method) do
      :slack -> send_slack_notification(message)
      _ -> log_notification(message)
    end
  end

  defp send_slack_notification(message) do
    %{message: message}
    |> SlackNotificationWorker.new()
    |> Oban.insert()
  end

  defp log_notification(message) do
    Logger.info("Notification: #{message}")
  end

  defp format_message(:user_registered, %{full_name: full_name, email: email}) do
    "✨ New user registered: #{full_name} (#{email})"
  end
end
