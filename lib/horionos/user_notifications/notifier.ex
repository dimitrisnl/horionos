defmodule Horionos.UserNotifications do
  @moduledoc """
  Module to send user notifications.
  """
  alias Horionos.Accounts.User
  alias Horionos.Organizations.Invitation
  alias Horionos.UserNotifications.Channels.Email
  alias Horionos.UserNotifications.Formatters.EmailFormatter

  @doc """
  Delivers an email.
  """
  @spec deliver(String.t(), atom(), map()) :: {:ok, map()} | {:error, term()}
  def deliver(email, template_key, assigns) do
    {subject, template, formatted_assigns} = EmailFormatter.format(template_key, assigns)
    Email.send(email, subject, template, formatted_assigns)
  end

  @doc """
  Deliver instructions to confirm account.
  """
  @spec deliver_confirmation_instructions(User.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, :confirmation_instructions, %{user: user, url: url})
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  @spec deliver_reset_password_instructions(User.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, :reset_password_instructions, %{user: user, url: url})
  end

  @doc """
  Deliver instructions to update a user email.
  """
  @spec deliver_update_email_instructions(User.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, :update_email_instructions, %{user: user, url: url})
  end

  @doc """
  Deliver an invitation to join an organization.
  """
  @spec deliver_invitation(Invitation.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def deliver_invitation(%Invitation{} = invitation, url) do
    deliver(invitation.email, :invitation, %{
      inviter: invitation.inviter,
      email: invitation.email,
      url: url,
      organization: invitation.organization
    })
  end
end
