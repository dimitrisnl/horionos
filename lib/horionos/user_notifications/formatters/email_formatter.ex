defmodule Horionos.UserNotifications.Formatters.EmailFormatter do
  @moduledoc """
  Module to format email notifications.
  """
  alias Horionos.Accounts.User

  @from_email Application.compile_env(:horionos, :from_email)
  @from_name Application.compile_env(:horionos, :from_name)

  def format(template_key, %User{} = user, assigns) do
    {subject, template, formatted_assigns} = do_format(template_key, user, assigns)
    {subject, template, Map.put(formatted_assigns, :from, sender_info())}
  end

  defp do_format(:confirmation_instructions, %User{} = user, %{url: url}) do
    {
      "Confirmation instructions",
      "confirmation_instructions",
      %{url: url, email: user.email}
    }
  end

  defp do_format(:reset_password_instructions, %User{} = user, %{url: url}) do
    {
      "Reset password instructions",
      "reset_password_instructions",
      %{url: url, email: user.email}
    }
  end

  defp do_format(:update_email_instructions, %User{} = user, %{url: url}) do
    {
      "Update email instructions",
      "update_email_instructions",
      %{url: url, email: user.email}
    }
  end

  def sender_info do
    %{name: @from_name, email: @from_email}
  end
end
