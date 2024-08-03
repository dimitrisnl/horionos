defmodule Horionos.Accounts.UserNotifier do
  @moduledoc """
  Handles sending notification emails to users.
  """

  alias Horionos.Workers.EmailWorker
  alias Horionos.Accounts.User

  require Logger

  @from_email Application.compile_env(:horionos, :from_email, "contact@horionos.com")
  @from_name Application.compile_env(:horionos, :from_name, "Horionos")

  @doc """
  Prepares and queues an email for delivery using Oban.
  """
  @spec deliver(String.t(), String.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  #
  def deliver(recipient, subject, template, assigns) do
    email_params = %{
      to: recipient,
      from: %{name: @from_name, email: @from_email},
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

  @doc """
  Deliver instructions to confirm account.
  """
  @spec deliver_confirmation_instructions(User.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  #
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", "confirmation_instructions.txt", %{
      url: url,
      email: user.email
    })
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  @spec deliver_reset_password_instructions(User.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  #
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Reset password instructions", "reset_password_instructions.txt", %{
      url: url,
      email: user.email
    })
  end

  @doc """
  Deliver instructions to update a user email.
  """
  @spec deliver_update_email_instructions(User.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  #
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", "update_email_instructions.txt", %{
      url: url,
      email: user.email
    })
  end

  @spec enqueue_email_job(map()) :: {:ok, map()} | {:error, term()}
  #
  defp enqueue_email_job(email_params) do
    %{email_params: email_params}
    |> EmailWorker.new()
    |> Oban.insert()
  end
end
