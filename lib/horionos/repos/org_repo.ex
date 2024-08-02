defmodule Horionos.OrgRepo do
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
  def all(queryable, org_id) do
    queryable
    |> scope_to_org(org_id)
    |> Repo.all()
  end

  @doc """
  Fetches a single record by id, scoped to an organization.
  """
  @spec get(Ecto.Queryable.t(), term(), integer()) :: Ecto.Schema.t() | nil
  def get(queryable, id, org_id) do
    queryable
    |> scope_to_org(org_id)
    |> Repo.get(id)
  end

  @doc """
  Fetches a single record by id, scoped to an organization. Raises if not found.
  """
  @spec get!(Ecto.Queryable.t(), term(), integer()) :: Ecto.Schema.t()
  def get!(queryable, id, org_id) do
    queryable
    |> scope_to_org(org_id)
    |> Repo.get!(id)
  end

  @doc """
  Fetches a single record by clauses, scoped to an organization.
  """
  @spec get_by(Ecto.Queryable.t(), Keyword.t() | map(), integer()) :: Ecto.Schema.t() | nil
  def get_by(queryable, clauses, org_id) do
    queryable
    |> scope_to_org(org_id)
    |> Repo.get_by(clauses)
  end

  @doc """
  Inserts a struct, setting the org_id.
  """
  @spec insert(Ecto.Changeset.t(), integer()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def insert(%Ecto.Changeset{} = changeset, org_id) do
    changeset
    |> Ecto.Changeset.put_change(:org_id, org_id)
    |> Repo.insert()
  end

  @doc """
  Updates a struct, ensuring it belongs to the given organization.
  """
  @spec update(Ecto.Changeset.t(), integer()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def update(%Ecto.Changeset{data: %{org_id: org_id}} = changeset, org_id) do
    Repo.update(changeset)
  end

  def update(%Ecto.Changeset{}, _org_id), do: {:error, :not_found}

  @doc """
  Deletes a struct, ensuring it belongs to the given organization.
  """
  @spec delete(Ecto.Schema.t(), integer()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def delete(%{org_id: org_id} = struct, org_id) do
    Repo.delete(struct)
  end

  def delete(_, _org_id), do: {:error, :not_found}

  @doc """
  Scopes a query to a specific organization.
  """
  @spec scope_to_org(Ecto.Queryable.t(), integer()) :: Ecto.Query.t()
  def scope_to_org(queryable, org_id) do
    from(q in queryable, where: q.org_id == ^org_id)
  end
end
