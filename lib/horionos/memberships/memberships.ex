defmodule Horionos.Memberships do
  @moduledoc false

  import Ecto.Query, warn: false
  alias Horionos.Repo
  alias Horionos.Memberships.Membership

  @doc """
    Gets all memberships for a user.

    ## Examples

        iex> list_memberships_by_user("123")
        [%Membership{}]

        iex> list_memberships_by_user("456")
        []

  """
  @spec list_memberships_by_user(String.t()) :: [Membership.t()]
  def list_memberships_by_user(user_id) do
    Repo.all(from m in Membership, where: m.user_id == ^user_id)
  end

  @doc """
    Gets all memberships for an organization.

    ## Examples

        iex> list_memberships_by_org("123")
        [%Membership{}]

        iex> list_memberships_by_org("456")
        []

  """
  @spec list_memberships_by_org(String.t()) :: [Membership.t()]
  def list_memberships_by_org(org_id) do
    Repo.all(from m in Membership, where: m.organization_id == ^org_id)
  end

  @doc """
  Gets a single membership.

  Raises `Ecto.NoResultsError` if the Membership does not exist.

  ## Examples

      iex> get_membership!(123)
      %Membership{}

      iex> get_membership!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_membership!(id :: String.t()) :: Membership.t()
  def get_membership!(id), do: Repo.get!(Membership, id)

  @doc """
  Creates a membership.

  ## Examples

      iex> create_membership(%{field: value})
      {:ok, %Membership{}}

      iex> create_membership(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_membership(map) :: {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}
  def create_membership(attrs \\ %{}) do
    %Membership{}
    |> Membership.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a membership.

  ## Examples

      iex> update_membership(membership, %{field: new_value})
      {:ok, %Membership{}}

      iex> update_membership(membership, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_membership(Membership.t(), map) ::
          {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}
  def update_membership(%Membership{} = membership, attrs) do
    membership
    |> Membership.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a membership.

  ## Examples

      iex> delete_membership(membership)
      {:ok, %Membership{}}

      iex> delete_membership(membership)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_membership(Membership.t()) :: {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}
  def delete_membership(%Membership{} = membership) do
    Repo.delete(membership)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking membership changes.

  ## Examples

      iex> change_membership(membership)
      %Ecto.Changeset{data: %Membership{}}

  """
  @spec change_membership(Membership.t(), map) :: Ecto.Changeset.t()
  def change_membership(%Membership{} = membership, attrs \\ %{}) do
    Membership.changeset(membership, attrs)
  end
end
