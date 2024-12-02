defmodule Horionos.Organizations.Organizations do
  @moduledoc """
  Basic organization management functions.
  """
  import Ecto.Query

  alias Horionos.Accounts.Schemas.User
  alias Horionos.Invitations.Schemas.Invitation
  alias Horionos.Memberships.Schemas.Membership
  alias Horionos.Organizations.Schemas.Organization
  alias Horionos.SystemAdmin.Notifier, as: SystemAdminNotifications

  alias Horionos.Repo

  @spec create_organization(User.t(), map()) ::
          {:ok, Organization.t()} | {:error, Ecto.Changeset.t()}
  def create_organization(%User{id: user_id}, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:organization, Organization.create_changeset(attrs))
    |> Ecto.Multi.insert(:membership, fn %{organization: organization} ->
      Membership.create_changeset(%{
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
    |> Organization.update_changeset(attrs)
    |> Repo.update()
  end

  @spec delete_organization(Organization.t()) :: {:ok, Organization.t()} | {:error, any()}
  def delete_organization(%Organization{id: organization_id} = organization) do
    result =
      Repo.transaction(fn ->
        # Delete associated records
        Repo.delete_all(from(m in Membership, where: m.organization_id == ^organization_id))
        Repo.delete_all(from(i in Invitation, where: i.organization_id == ^organization_id))

        # Finally, delete the organization
        Repo.delete!(organization)
      end)

    case result do
      {:ok, _} ->
        SystemAdminNotifications.notify(:organization_deleted, %{organization: organization})
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

  @spec build_organization_changeset(Organization.t(), map()) :: Ecto.Changeset.t()
  def build_organization_changeset(%Organization{} = organization, attrs \\ %{}) do
    Organization.update_changeset(organization, attrs)
  end
end
