defmodule Horionos.AdminNotifications do
  @moduledoc """
  Module to send admin notifications.
  """
  alias Horionos.Admin.Channels.Slack
  alias Horionos.Admin.MessageFormatter

  require Logger

  def notify(event, details) do
    message = MessageFormatter.format(event, details)

    case Application.get_env(:horionos, :admin_notification_method) do
      :slack -> Slack.send(message)
      _ -> log_notification(message)
    end
  end

  defp log_notification(message) do
    Logger.info("Admin Notification: #{message}")
  end
end
