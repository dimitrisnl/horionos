defmodule Horionos.UserNotifications.Channels.Email do
  @moduledoc """
  Module to send user notifications via email.
  """
  alias Horionos.Workers.EmailWorker

  require Logger

  @doc """
  Prepares and queues an email for delivery using Oban.
  """
  @spec send(String.t(), String.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def send(recipient, subject, template, assigns) do
    email_params = %{
      to: recipient,
      from: Map.get(assigns, :from, %{}),
      subject: subject,
      template: template,
      assigns: Map.drop(assigns, [:from])
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
