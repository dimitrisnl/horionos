defmodule Horionos.Orgs do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Horionos.Repo
  alias Horionos.Orgs.Org

  @doc """
  Returns the list of orgs.

  ## Examples

      iex> list_orgs()
      [%Org{}, ...]

  """
  @spec list_orgs() :: [Org.t()]
  def list_orgs do
    Repo.all(Org)
  end

  @doc """
  Gets a single org.

  Raises `Ecto.NoResultsError` if the Org does not exist.

  ## Examples

      iex> get_org!(123)
      %Org{}

      iex> get_org!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_org!(id :: String.t()) :: Org.t()
  def get_org!(id), do: Repo.get!(Org, id)

  @doc """
  Creates a org.

  ## Examples

      iex> create_org(%{field: value})
      {:ok, %Org{}}

      iex> create_org(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_org(map) :: {:ok, Org.t()} | {:error, Ecto.Changeset.t()}
  def create_org(attrs \\ %{}) do
    %Org{}
    |> Org.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a org.

  ## Examples

      iex> update_org(org, %{field: new_value})
      {:ok, %Org{}}

      iex> update_org(org, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_org(Org.t(), map) :: {:ok, Org.t()} | {:error, Ecto.Changeset.t()}
  def update_org(%Org{} = org, attrs) do
    org
    |> Org.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a org.

  ## Examples

      iex> delete_org(org)
      {:ok, %Org{}}

      iex> delete_org(org)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_org(Org.t()) :: {:ok, Org.t()} | {:error, Ecto.Changeset.t()}
  def delete_org(%Org{} = org) do
    Repo.delete(org)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking org changes.

  ## Examples

      iex> change_org(org)
      %Ecto.Changeset{data: %Org{}}

  """
  @spec change_org(Org.t(), map) :: Ecto.Changeset.t()
  def change_org(%Org{} = org, attrs \\ %{}) do
    Org.changeset(org, attrs)
  end
end
