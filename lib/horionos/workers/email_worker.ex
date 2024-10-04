defmodule Horionos.Workers.EmailWorker do
  @moduledoc """
  Worker for sending emails.
  """
  use Oban.Worker, queue: :emails

  import Swoosh.Email

  alias Horionos.Mailer

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"email_params" => email_params}}) do
    email_params
    |> Mailer.from_map()
    |> create_email()
    |> Mailer.deliver()

    :ok
  end

  defp create_email(%{to: to, from: from, subject: subject, template: template, assigns: assigns}) do
    new()
    |> to(to)
    |> from(from)
    |> subject(subject)
    |> render_body(template, string_keys_to_atoms(assigns))
  end

  defp render_body(email, template, assigns) do
    body =
      template
      |> template_file()
      |> EEx.eval_file(assigns: assigns)

    text_body(email, body)
  end

  defp template_file(template) do
    Application.app_dir(:horionos, "priv/email_templates/#{template}.txt.eex")
  end

  defp string_keys_to_atoms(map) do
    Map.new(map, fn {k, v} -> {String.to_existing_atom(k), v} end)
  end
end
