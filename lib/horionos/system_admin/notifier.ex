defmodule Horionos.SystemAdmin.Notifier do
  @moduledoc """
  Module to send admin notifications.
  """
  alias Horionos.SystemAdmin.Channels.Slack
  alias Horionos.SystemAdmin.MessageFormatter

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
