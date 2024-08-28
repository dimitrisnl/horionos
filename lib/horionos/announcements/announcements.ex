defmodule Horionos.Announcements do
  @moduledoc """
  The Announcements context.
  """

  import Ecto.Query

  alias Horionos.Announcements.Announcement
  alias Horionos.OrgRepo
  alias Horionos.Orgs.Org

  @doc """
  Returns the list of announcements for a given organization.
  """
  @spec list_announcements(Org.t()) :: [Announcement.t()]
  def list_announcements(%Org{} = org) do
    Announcement
    |> where([a], a.org_id == ^org.id)
    |> order_by([a], desc: a.inserted_at)
    |> OrgRepo.all(org.id)
  end

  @doc """
  Gets a single announcement.
  """
  @spec get_announcement(Org.t(), integer()) :: {:ok, Announcement.t()} | {:error, :not_found}
  def get_announcement(%Org{} = org, id) do
    case OrgRepo.get(Announcement, id, org.id) do
      nil -> {:error, :not_found}
      announcement -> {:ok, announcement}
    end
  end

  @doc """
  Creates an announcement.
  """
  @spec create_announcement(Org.t(), map()) ::
          {:ok, Announcement.t()} | {:error, Ecto.Changeset.t()}
  def create_announcement(%Org{} = org, attrs) do
    %Announcement{}
    |> Announcement.changeset(attrs)
    |> OrgRepo.insert(org.id)
  end

  @doc """
  Updates an announcement.
  """
  @spec update_announcement(Announcement.t(), map()) ::
          {:ok, Announcement.t()} | {:error, Ecto.Changeset.t()}
  def update_announcement(%Announcement{} = announcement, attrs) do
    announcement
    |> Announcement.changeset(attrs)
    |> OrgRepo.update(announcement.org_id)
  end

  @doc """
  Deletes an announcement.
  """
  @spec delete_announcement(Announcement.t()) ::
          {:ok, Announcement.t()} | {:error, Ecto.Changeset.t()}
  def delete_announcement(%Announcement{} = announcement) do
    OrgRepo.delete(announcement, announcement.org_id)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking announcement changes.
  """
  @spec build_announcement_changeset(Announcement.t(), map()) :: Ecto.Changeset.t()
  def build_announcement_changeset(%Announcement{} = announcement, attrs \\ %{}) do
    Announcement.changeset(announcement, attrs)
  end
end
