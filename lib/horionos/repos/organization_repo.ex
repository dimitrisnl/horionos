defmodule Horionos.OrganizationRepo do
  @moduledoc """
  Provides organization-scoped database operations.
  This module ensures that all operations are scoped to a specific organization.
  """

  import Ecto.Query
  alias Horionos.Repo

  @doc """
  Fetches all records for a given queryable, scoped to an organization.
  """
  @spec all(Ecto.Queryable.t(), integer()) :: [Ecto.Schema.t()]
  def all(queryable, organization_id) do
    queryable
    |> scope_to_organization(organization_id)
    |> Repo.all()
  end

  @doc """
  Fetches a single record by id, scoped to an organization.
  """
  @spec get(Ecto.Queryable.t(), term(), integer()) :: Ecto.Schema.t() | nil
  def get(queryable, id, organization_id) do
    queryable
    |> scope_to_organization(organization_id)
    |> Repo.get(id)
  end

  @doc """
  Fetches a single record by id, scoped to an organization. Raises if not found.
  """
  @spec get!(Ecto.Queryable.t(), term(), integer()) :: Ecto.Schema.t()
  def get!(queryable, id, organization_id) do
    queryable
    |> scope_to_organization(organization_id)
    |> Repo.get!(id)
  end

  @doc """
  Fetches a single record by clauses, scoped to an organization.
  """
  @spec get_by(Ecto.Queryable.t(), Keyword.t() | map(), integer()) :: Ecto.Schema.t() | nil
  def get_by(queryable, clauses, organization_id) do
    queryable
    |> scope_to_organization(organization_id)
    |> Repo.get_by(clauses)
  end

  @doc """
  Inserts a struct, setting the organization_id.
  """
  @spec insert(Ecto.Changeset.t(), integer()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def insert(%Ecto.Changeset{} = changeset, organization_id) do
    changeset
    |> Ecto.Changeset.put_change(:organization_id, organization_id)
    |> Repo.insert()
  end

  @doc """
  Updates a struct, ensuring it belongs to the given organization.
  """
  @spec update(Ecto.Changeset.t(), integer()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def update(
        %Ecto.Changeset{data: %{organization_id: organization_id}} = changeset,
        organization_id
      ) do
    Repo.update(changeset)
  end

  def update(%Ecto.Changeset{}, _organization_id), do: {:error, :not_found}

  @doc """
  Deletes a struct, ensuring it belongs to the given organization.
  """
  @spec delete(Ecto.Schema.t(), integer()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def delete(%{organization_id: organization_id} = struct, organization_id) do
    Repo.delete(struct)
  end

  def delete(_, _organization_id), do: {:error, :not_found}

  @doc """
  Scopes a query to a specific organization.
  """
  @spec scope_to_organization(Ecto.Queryable.t(), integer()) :: Ecto.Query.t()
  def scope_to_organization(queryable, organization_id) do
    from(q in queryable, where: q.organization_id == ^organization_id)
  end
end
