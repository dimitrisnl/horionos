defmodule HorionosWeb.OrgHTML do
  use HorionosWeb, :html

  embed_templates "org_html/*"

  @doc """
  Renders a org form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def org_form(assigns)
end
