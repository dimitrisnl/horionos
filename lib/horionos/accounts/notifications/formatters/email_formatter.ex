defmodule Horionos.Accounts.Notifications.Formatters.EmailFormatter do
  @moduledoc """
  Module to format email notifications.
  """
  alias Horionos.Accounts.Schemas.User
  alias Horionos.Constants
  alias Horionos.Organizations.Schemas.Organization

  @from_email Constants.from_email()
  @from_name Constants.from_name()

  def format(template_key, assigns) do
    {email, subject, template, formatted_assigns} = do_format(template_key, assigns)
    {email, subject, template, formatted_assigns, sender_info()}
  end

  defp do_format(:confirm_email_instructions, %{user: %User{} = user, url: url}) do
    {
      user.email,
      "Confirmation instructions",
      "confirm_email_instructions",
      %{url: url, email: user.email}
    }
  end

  defp do_format(:reset_password_instructions, %{user: %User{} = user, url: url}) do
    {
      user.email,
      "Reset password instructions",
      "reset_password_instructions",
      %{url: url, email: user.email}
    }
  end

  defp do_format(:update_email_instructions, %{user: %User{} = user, url: url}) do
    {
      user.email,
      "Update email instructions",
      "update_email_instructions",
      %{url: url, email: user.email}
    }
  end

  defp do_format(:new_invitation, %{
         inviter: %User{} = inviter,
         email: email,
         url: url,
         organization: %Organization{} = organization
       }) do
    {
      email,
      "Invitation to join #{organization.title}",
      "new_invitation",
      %{url: url, inviter: inviter.full_name, organization: organization.title, email: email}
    }
  end

  def sender_info do
    %{name: @from_name, email: @from_email}
  end
end
