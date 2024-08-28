defmodule Horionos.Orgs.OrganizationManagement do
  @moduledoc """
  This module provides functions for managing organizations.
  """
  import Ecto.Query

  alias Horionos.Accounts.User
  alias Horionos.Announcements.Announcement
  alias Horionos.Orgs.{Invitation, Membership, Org}
  alias Horionos.Repo

  @spec create_org(User.t(), map()) :: {:ok, Org.t()} | {:error, Ecto.Changeset.t()}
  def create_org(%User{id: user_id}, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:org, Org.changeset(%Org{}, attrs))
    |> Ecto.Multi.insert(:membership, fn %{org: org} ->
      Membership.changeset(%Membership{}, %{
        user_id: user_id,
        org_id: org.id,
        role: :owner
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{org: org}} -> {:ok, org}
      {:error, _operation, changeset, _changes} -> {:error, changeset}
    end
  end

  @spec update_org(Org.t(), map()) :: {:ok, Org.t()} | {:error, Ecto.Changeset.t()}
  def update_org(%Org{} = org, attrs) do
    org
    |> Org.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_org(Org.t()) :: {:ok, Org.t()} | {:error, any()}
  def delete_org(%Org{id: org_id} = org) do
    Repo.transaction(fn ->
      # Delete associated records
      Repo.delete_all(from(m in Membership, where: m.org_id == ^org_id))
      Repo.delete_all(from(a in Announcement, where: a.org_id == ^org_id))
      Repo.delete_all(from(i in Invitation, where: i.org_id == ^org_id))

      # Finally, delete the org
      Repo.delete!(org)
    end)
  end

  @spec list_user_orgs(User.t()) :: [Org.t()]
  def list_user_orgs(%User{id: user_id}) do
    Membership
    |> where([m], m.user_id == ^user_id)
    |> join(:inner, [m], o in Org, on: m.org_id == o.id)
    |> select([m, o], o)
    |> Repo.all()
  end

  @spec get_org(integer() | String.t()) ::
          {:ok, Org.t()} | {:error, :invalid_org_id} | {:error, :not_found}
  def get_org(org_id) when is_binary(org_id) do
    case Integer.parse(org_id) do
      {id, ""} -> get_org(id)
      _ -> {:error, :invalid_org_id}
    end
  end

  def get_org(org_id) when is_integer(org_id) do
    case Repo.get(Org, org_id) do
      nil -> {:error, :not_found}
      org -> {:ok, org}
    end
  end

  @spec get_user_primary_org(User.t()) :: Org.t() | nil
  def get_user_primary_org(%User{id: user_id}) do
    Repo.one(
      from o in Org,
        join: m in Membership,
        on: m.org_id == o.id,
        where: m.user_id == ^user_id,
        order_by: [asc: m.inserted_at],
        limit: 1
    )
  end

  @spec build_org_changeset(Org.t(), map()) :: Ecto.Changeset.t()
  def build_org_changeset(%Org{} = org, attrs \\ %{}) do
    Org.changeset(org, attrs)
  end
end
