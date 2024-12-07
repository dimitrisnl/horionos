defmodule Horionos.Accounts.Notifications.Channels.Email do
  @moduledoc """
  Email notification channel
  """
  alias Horionos.Accounts.Notifications.Formatters.EmailFormatter
  alias Horionos.Workers.EmailWorker

  require Logger

  @spec deliver(atom(), map()) :: {:ok, map()} | {:error, term()}
  def deliver(notification_key, assigns) do
    {email, subject, template, assigns, from} = EmailFormatter.format(notification_key, assigns)

    email_params = %{
      to: email,
      from: from,
      subject: subject,
      template: template,
      assigns: assigns
    }

    case enqueue_email_job(email_params) do
      {:ok, _job} ->
        {:ok, email_params}

      {:error, reason} ->
        Logger.error("Failed to enqueue email job: #{reason}")
        {:error, reason}
    end
  end

  @spec enqueue_email_job(map()) :: {:ok, map()} | {:error, term()}
  defp enqueue_email_job(email_params) do
    %{email_params: email_params}
    |> EmailWorker.new()
    |> Oban.insert()
  end
end
