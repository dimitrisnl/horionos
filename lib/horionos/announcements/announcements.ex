defmodule Horionos.Announcements do
  @moduledoc """
  The Announcements context.
  """

  import Ecto.Query

  alias Horionos.Announcements.Announcement
  alias Horionos.OrganizationRepo
  alias Horionos.Organizations.Organization

  @doc """
  Returns the list of announcements for a given organization.
  """
  @spec list_announcements(Organization.t()) :: [Announcement.t()]
  def list_announcements(%Organization{} = organization) do
    Announcement
    |> where([a], a.organization_id == ^organization.id)
    |> order_by([a], desc: a.inserted_at)
    |> OrganizationRepo.all(organization.id)
  end

  @doc """
  Gets a single announcement.
  """
  @spec get_announcement(Organization.t(), integer()) ::
          {:ok, Announcement.t()} | {:error, :not_found}
  def get_announcement(%Organization{} = organization, id) do
    case OrganizationRepo.get(Announcement, id, organization.id) do
      nil -> {:error, :not_found}
      announcement -> {:ok, announcement}
    end
  end

  @doc """
  Creates an announcement.
  """
  @spec create_announcement(Organization.t(), map()) ::
          {:ok, Announcement.t()} | {:error, Ecto.Changeset.t()}
  def create_announcement(%Organization{} = organization, attrs) do
    %Announcement{}
    |> Announcement.changeset(attrs)
    |> OrganizationRepo.insert(organization.id)
  end

  @doc """
  Updates an announcement.
  """
  @spec update_announcement(Announcement.t(), map()) ::
          {:ok, Announcement.t()} | {:error, Ecto.Changeset.t()}
  def update_announcement(%Announcement{} = announcement, attrs) do
    announcement
    |> Announcement.changeset(attrs)
    |> OrganizationRepo.update(announcement.organization_id)
  end

  @doc """
  Deletes an announcement.
  """
  @spec delete_announcement(Announcement.t()) ::
          {:ok, Announcement.t()} | {:error, Ecto.Changeset.t()}
  def delete_announcement(%Announcement{} = announcement) do
    OrganizationRepo.delete(announcement, announcement.organization_id)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking announcement changes.
  """
  @spec build_announcement_changeset(Announcement.t(), map()) :: Ecto.Changeset.t()
  def build_announcement_changeset(%Announcement{} = announcement, attrs \\ %{}) do
    Announcement.changeset(announcement, attrs)
  end
end
