defmodule Horionos.Organizations.Helpers.SlugGenerator do
  @moduledoc """
  Helper module to generate unique slugs
  """

  alias Horionos.Repo

  @max_slug_attempts 100

  @spec generate_unique_slug(module(), String.t(), Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def generate_unique_slug(schema, title, changeset) do
    base_slug =
      title
      |> String.downcase()
      |> String.replace(~r/[^\w-]+/, "-")
      |> String.trim("-")

    case find_unique_slug(schema, base_slug) do
      {:ok, slug} ->
        Ecto.Changeset.put_change(changeset, :slug, slug)

      {:error, _reason} ->
        Ecto.Changeset.add_error(changeset, :title, "Unable to generate a unique slug")
    end
  end

  defp find_unique_slug(schema, base_slug, attempt \\ 0) do
    slug = if attempt == 0, do: base_slug, else: "#{base_slug}-#{attempt}"

    case Repo.get_by(schema, slug: slug) do
      nil ->
        {:ok, slug}

      _ ->
        if attempt < @max_slug_attempts do
          find_unique_slug(schema, base_slug, attempt + 1)
        else
          {:error, :max_attempts_reached}
        end
    end
  end
end
