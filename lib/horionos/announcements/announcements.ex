defmodule Horionos.Announcements do
  @moduledoc """
  The Announcements context.
  """

  import Ecto.Query

  alias Horionos.Accounts.User
  alias Horionos.Announcements.Announcement
  alias Horionos.OrgRepo
  alias Horionos.Orgs.Org
  alias Horionos.Authorization

  @doc """
  Returns the list of announcements for a given organization.
  """
  @spec list_announcements(User.t(), Org.t()) ::
          {:ok, [Announcement.t()]} | {:error, Authorization.error()}
  def list_announcements(%User{} = user, %Org{} = org) do
    Authorization.with_authorization(user, org, :announcement_view, fn ->
      announcements =
        Announcement
        |> where([a], a.org_id == ^org.id)
        |> order_by([a], desc: a.inserted_at)
        |> OrgRepo.all(org.id)

      {:ok, announcements}
    end)
  end

  @doc """
  Gets a single announcement.
  """
  @spec get_announcement(User.t(), Org.t(), integer()) ::
          {:ok, Announcement.t()} | {:error, :not_found | Authorization.error()}
  def get_announcement(%User{} = user, %Org{} = org, id) do
    Authorization.with_authorization(user, org, :announcement_view, fn ->
      case OrgRepo.get(Announcement, id, org.id) do
        nil -> {:error, :not_found}
        announcement -> {:ok, announcement}
      end
    end)
  end

  @doc """
  Creates an announcement.
  """
  @spec create_announcement(User.t(), Org.t(), map()) ::
          {:ok, Announcement.t()} | {:error, Ecto.Changeset.t() | Authorization.error()}
  def create_announcement(%User{} = user, %Org{} = org, attrs) do
    Authorization.with_authorization(user, org, :announcement_create, fn ->
      %Announcement{}
      |> Announcement.changeset(attrs)
      |> OrgRepo.insert(org.id)
    end)
  end

  @doc """
  Updates an announcement.
  """
  @spec update_announcement(User.t(), Announcement.t(), map()) ::
          {:ok, Announcement.t()} | {:error, Ecto.Changeset.t() | Authorization.error()}
  def update_announcement(%User{} = user, %Announcement{} = announcement, attrs) do
    org = %Org{id: announcement.org_id}

    Authorization.with_authorization(user, org, :announcement_edit, fn ->
      announcement
      |> Announcement.changeset(attrs)
      |> OrgRepo.update(announcement.org_id)
    end)
  end

  @doc """
  Deletes an announcement.
  """
  @spec delete_announcement(User.t(), Announcement.t()) ::
          {:ok, Announcement.t()} | {:error, Ecto.Changeset.t() | Authorization.error()}
  def delete_announcement(%User{} = user, %Announcement{} = announcement) do
    org = %Org{id: announcement.org_id}

    Authorization.with_authorization(user, org, :announcement_delete, fn ->
      OrgRepo.delete(announcement, announcement.org_id)
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking announcement changes.
  """
  @spec build_announcement_changeset(Announcement.t(), map()) :: Ecto.Changeset.t()
  def build_announcement_changeset(%Announcement{} = announcement, attrs \\ %{}) do
    Announcement.changeset(announcement, attrs)
  end
end
