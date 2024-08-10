defmodule Horionos.Announcements do
  @moduledoc """
  The Announcements context.
  """

  import Ecto.Query

  alias Horionos.Accounts.User
  alias Horionos.Announcements.Announcement
  alias Horionos.OrgRepo
  alias Horionos.Orgs

  @doc """
  Returns the list of announcements for a given organization.
  """
  @spec list_announcements(User.t(), integer()) ::
          {:ok, [Announcement.t()]} | {:error, :unauthorized}
  #
  def list_announcements(%User{} = user, org_id) do
    with :ok <- Orgs.authorize_user(user, org_id, :member) do
      announcements =
        Announcement
        |> where([a], a.org_id == ^org_id)
        |> order_by([a], desc: a.inserted_at)
        |> OrgRepo.all(org_id)

      {:ok, announcements}
    end
  end

  @doc """
  Gets a single announcement.
  """
  @spec get_announcement(User.t(), integer(), integer()) ::
          {:ok, Announcement.t()} | {:error, :not_found | :unauthorized}
  #
  def get_announcement(%User{} = user, id, org_id) do
    with :ok <- Orgs.authorize_user(user, org_id, :member) do
      case OrgRepo.get(Announcement, id, org_id) do
        nil -> {:error, :not_found}
        announcement -> {:ok, announcement}
      end
    end
  end

  @doc """
  Creates an announcement.
  """
  @spec create_announcement(User.t(), integer(), map()) ::
          {:ok, Announcement.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  #
  def create_announcement(%User{} = user, org_id, attrs) do
    with :ok <- Orgs.authorize_user(user, org_id, :member) do
      %Announcement{}
      |> Announcement.changeset(attrs)
      |> OrgRepo.insert(org_id)
    end
  end

  @doc """
  Updates an announcement.
  """
  @spec update_announcement(User.t(), Announcement.t(), map()) ::
          {:ok, Announcement.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  #
  def update_announcement(%User{} = user, %Announcement{} = announcement, attrs) do
    with :ok <- Orgs.authorize_user(user, announcement.org_id, :member) do
      announcement
      |> Announcement.changeset(attrs)
      |> OrgRepo.update(announcement.org_id)
    end
  end

  @doc """
  Deletes an announcement.
  """
  @spec delete_announcement(User.t(), Announcement.t()) ::
          {:ok, Announcement.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  #
  def delete_announcement(%User{} = user, %Announcement{} = announcement) do
    with :ok <- Orgs.authorize_user(user, announcement.org_id, :member) do
      OrgRepo.delete(announcement, announcement.org_id)
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking announcement changes.
  """
  @spec build_announcement_changeset(Announcement.t(), map()) :: Ecto.Changeset.t()
  #
  def build_announcement_changeset(%Announcement{} = announcement, attrs \\ %{}) do
    Announcement.changeset(announcement, attrs)
  end
end
