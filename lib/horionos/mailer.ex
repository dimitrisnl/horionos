defmodule Horionos.Mailer do
  use Swoosh.Mailer, otp_app: :horionos

  @moduledoc """
  Mailer module
  Utilizes Swoosh for email delivery.
  """

  def to_map(email_params), do: email_params

  def from_map(email_params) do
    %{
      to: map_to_contact(email_params["to"]),
      from: map_to_contact(email_params["from"]),
      subject: email_params["subject"],
      template: email_params["template"],
      assigns: email_params["assigns"]
    }
  end

  defp map_to_contact(%{"name" => name, "email" => email}), do: {name, email}
  defp map_to_contact(email) when is_binary(email), do: email
end
