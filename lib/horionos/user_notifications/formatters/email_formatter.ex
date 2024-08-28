defmodule Horionos.UserNotifications.Formatters.EmailFormatter do
  @moduledoc """
  Module to format email notifications.
  """
  alias Horionos.Accounts.User
  alias Horionos.Organizations.Organization

  @from_email Application.compile_env(:horionos, :from_email)
  @from_name Application.compile_env(:horionos, :from_name)

  def format(template_key, assigns) do
    {subject, template, formatted_assigns} = do_format(template_key, assigns)
    {subject, template, Map.put(formatted_assigns, :from, sender_info())}
  end

  defp do_format(:confirmation_instructions, %{user: %User{} = user, url: url}) do
    {
      "Confirmation instructions",
      "confirmation_instructions",
      %{url: url, email: user.email}
    }
  end

  defp do_format(:reset_password_instructions, %{user: %User{} = user, url: url}) do
    {
      "Reset password instructions",
      "reset_password_instructions",
      %{url: url, email: user.email}
    }
  end

  defp do_format(:update_email_instructions, %{user: %User{} = user, url: url}) do
    {
      "Update email instructions",
      "update_email_instructions",
      %{url: url, email: user.email}
    }
  end

  defp do_format(:invitation, %{
         inviter: %User{} = inviter,
         email: email,
         url: url,
         organization: %Organization{} = organization
       }) do
    {
      "Invitation to join #{organization.title}",
      "invitation",
      %{url: url, inviter: inviter.full_name, organization: organization.title, email: email}
    }
  end

  def sender_info do
    %{name: @from_name, email: @from_email}
  end
end
