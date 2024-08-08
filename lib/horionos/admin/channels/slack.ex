defmodule Horionos.Admin.Channels.Slack do
  @moduledoc """
  Module to send Slack notifications.
  """
  alias Horionos.Workers.SlackNotificationWorker

  def send(message) do
    %{message: message}
    |> SlackNotificationWorker.new()
    |> Oban.insert()
  end
end
