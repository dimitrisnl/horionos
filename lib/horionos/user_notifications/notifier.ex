defmodule Horionos.UserNotifications do
  @moduledoc """
  Module to send user notifications.
  """
  alias Horionos.Accounts.User
  alias Horionos.UserNotifications.Channels.Email
  alias Horionos.UserNotifications.Formatters.EmailFormatter

  @doc """
  Delivers a user email.
  """
  @spec deliver(User.t(), atom(), map()) :: {:ok, map()} | {:error, term()}
  def deliver(%User{} = user, template_key, assigns) do
    {subject, template, formatted_assigns} = EmailFormatter.format(template_key, user, assigns)
    Email.send(user.email, subject, template, formatted_assigns)
  end

  @doc """
  Deliver instructions to confirm account.
  """
  @spec deliver_confirmation_instructions(User.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def deliver_confirmation_instructions(user, url) do
    deliver(user, :confirmation_instructions, %{url: url})
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  @spec deliver_reset_password_instructions(User.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def deliver_reset_password_instructions(user, url) do
    deliver(user, :reset_password_instructions, %{url: url})
  end

  @doc """
  Deliver instructions to update a user email.
  """
  @spec deliver_update_email_instructions(User.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def deliver_update_email_instructions(user, url) do
    deliver(user, :update_email_instructions, %{url: url})
  end
end
