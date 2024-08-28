defmodule Horionos.Organizations.OrganizationManagement do
  @moduledoc """
  This module provides functions for managing organizations.
  """
  import Ecto.Query

  alias Horionos.Accounts.User
  alias Horionos.AdminNotifications
  alias Horionos.Announcements.Announcement
  alias Horionos.Organizations.{Invitation, Membership, Organization}
  alias Horionos.Repo

  @spec create_organization(User.t(), map()) ::
          {:ok, Organization.t()} | {:error, Ecto.Changeset.t()}
  def create_organization(%User{id: user_id}, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:organization, Organization.changeset(%Organization{}, attrs))
    |> Ecto.Multi.insert(:membership, fn %{organization: organization} ->
      Membership.changeset(%Membership{}, %{
        user_id: user_id,
        organization_id: organization.id,
        role: :owner
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{organization: organization}} -> {:ok, organization}
      {:error, _operation, changeset, _changes} -> {:error, changeset}
    end
  end

  @spec update_organization(Organization.t(), map()) ::
          {:ok, Organization.t()} | {:error, Ecto.Changeset.t()}
  def update_organization(%Organization{} = organization, attrs) do
    organization
    |> Organization.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_organization(Organization.t()) :: {:ok, Organization.t()} | {:error, any()}
  def delete_organization(%Organization{id: organization_id} = organization) do
    result =
      Repo.transaction(fn ->
        # Delete associated records
        Repo.delete_all(from(m in Membership, where: m.organization_id == ^organization_id))
        Repo.delete_all(from(a in Announcement, where: a.organization_id == ^organization_id))
        Repo.delete_all(from(i in Invitation, where: i.organization_id == ^organization_id))

        # Finally, delete the organization
        Repo.delete!(organization)
      end)

    case result do
      {:ok, _} ->
        AdminNotifications.notify(:organization_deleted, %{organization: organization})
        {:ok, organization}

      _ ->
        result
    end
  end

  @spec get_organization(integer() | String.t()) ::
          {:ok, Organization.t()} | {:error, :invalid_organization_id} | {:error, :not_found}
  def get_organization(organization_id) when is_binary(organization_id) do
    case Integer.parse(organization_id) do
      {id, ""} -> get_organization(id)
      _ -> {:error, :invalid_organization_id}
    end
  end

  def get_organization(organization_id) when is_integer(organization_id) do
    case Repo.get(Organization, organization_id) do
      nil -> {:error, :not_found}
      organization -> {:ok, organization}
    end
  end

  @spec get_user_primary_organization(User.t()) :: Organization.t() | nil
  def get_user_primary_organization(%User{id: user_id}) do
    Repo.one(
      from o in Organization,
        join: m in Membership,
        on: m.organization_id == o.id,
        where: m.user_id == ^user_id,
        order_by: [asc: m.inserted_at],
        limit: 1
    )
  end

  @spec build_organization_changeset(Organization.t(), map()) :: Ecto.Changeset.t()
  def build_organization_changeset(%Organization{} = organization, attrs \\ %{}) do
    Organization.changeset(organization, attrs)
  end
end
