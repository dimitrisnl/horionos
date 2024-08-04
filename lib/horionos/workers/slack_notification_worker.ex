defmodule Horionos.Workers.SlackNotificationWorker do
  @moduledoc """
  Sends a notification to a Slack webhook.
  """
  use Oban.Worker, queue: :notifications
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"message" => message}}) do
    webhook_url = System.get_env("SLACK_WEBHOOK_URL")

    case HTTPoison.post(webhook_url, Jason.encode!(%{text: message}), [
           {"Content-Type", "application/json"}
         ]) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        Logger.info("Slack notification sent successfully")
        :ok

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("Slack notification failed. Status: #{status_code}, Body: #{body}")
        {:error, "Slack notification failed"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Slack notification error: #{inspect(reason)}")
        {:error, "Slack notification error"}
    end

    :ok
  end
end
