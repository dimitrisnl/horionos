defmodule Horionos.Orgs do
  @moduledoc """
  The Orgs context.
  Handles operations related to organizations and memberships,
  with access control based on user permissions.
  """

  import Ecto.Query

  alias Horionos.Repo

  alias Horionos.Accounts.User
  alias Horionos.Announcements.Announcement
  alias Horionos.OrgRepo
  alias Horionos.Orgs.{Membership, MembershipRole, Org}

  @doc """
  Lists organizations for a given user.
  """
  @spec list_user_orgs(User.t()) :: [Org.t()]
  #
  def list_user_orgs(%User{id: user_id}) do
    Membership
    |> where([m], m.user_id == ^user_id)
    |> join(:inner, [m], o in Org, on: m.org_id == o.id)
    |> select([m, o], o)
    |> Repo.all()
  end

  @doc """
  Gets a single org for a user.
  Returns nil if the user doesn't have access to the org.
  """
  @spec get_org(User.t(), String.t()) :: {:ok, Org.t()} | {:error, :unauthorized}
  #
  def get_org(%User{id: user_id}, org_id) do
    org =
      Membership
      |> where([m], m.user_id == ^user_id and m.org_id == ^org_id)
      |> join(:inner, [m], o in Org, on: m.org_id == o.id)
      |> select([m, o], o)
      |> Repo.one()

    case org do
      nil -> {:error, :unauthorized}
      org -> {:ok, org}
    end
  end

  @doc """
  Creates an org and adds the user as an owner.
  """
  @spec create_org(User.t(), map()) :: {:ok, Org.t()} | {:error, Ecto.Changeset.t()}
  #
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

  @doc """
  Updates an org if the user has appropriate permissions.
  """
  @spec update_org(User.t(), Org.t(), map()) ::
          {:ok, Org.t()} | {:error, Ecto.Changeset.t()} | {:error, :unauthorized}
  #
  def update_org(%User{id: user_id}, %Org{id: org_id} = org, attrs) do
    with {:ok, role} <- get_user_role(user_id, org_id),
         true <- MembershipRole.at_least?(role, :admin) do
      org
      |> Org.changeset(attrs)
      |> Repo.update()
    else
      _ -> {:error, :unauthorized}
    end
  end

  @doc """
  Deletes an org if the user is the owner.
  """
  @spec delete_org(User.t(), Org.t()) ::
          {:ok, Org.t()} | {:error, Ecto.Changeset.t()} | {:error, :unauthorized}
  #
  def delete_org(%User{id: user_id}, %Org{id: org_id} = org) do
    with {:ok, role} <- get_user_role(user_id, org_id),
         true <- MembershipRole.owner?(role) do
      case Repo.transaction(fn ->
             # Delete associated records
             Repo.delete_all(from(m in Membership, where: m.org_id == ^org_id))
             Repo.delete_all(from(a in Announcement, where: a.org_id == ^org_id))

             # Finally, delete the org
             Repo.delete!(org)
           end) do
        {:ok, _} -> {:ok, org}
        {:error, error} -> {:error, error}
      end
    else
      _ -> {:error, :unauthorized}
    end
  end

  @doc """
  Creates a membership if the user has appropriate permissions.
  """
  @spec create_membership(User.t(), map()) ::
          {:ok, Membership.t()} | {:error, Ecto.Changeset.t()} | {:error, :unauthorized}
  #
  def create_membership(%User{id: user_id}, attrs) do
    with {:ok, role} <- get_user_role(user_id, attrs.org_id),
         true <- MembershipRole.at_least?(role, :admin) do
      %Membership{}
      |> Membership.changeset(attrs)
      |> OrgRepo.insert(attrs.org_id)
    else
      _ -> {:error, :unauthorized}
    end
  end

  @doc """
  Updates a membership if the user has appropriate permissions.
  """
  @spec update_membership(User.t(), Membership.t(), map()) ::
          {:ok, Membership.t()} | {:error, Ecto.Changeset.t()} | {:error, :unauthorized}
  #
  def update_membership(%User{id: user_id}, %Membership{org_id: org_id} = membership, attrs) do
    with {:ok, role} <- get_user_role(user_id, org_id),
         true <- MembershipRole.at_least?(role, :admin) do
      membership
      |> Membership.changeset(attrs)
      |> OrgRepo.update(org_id)
    else
      _ -> {:error, :unauthorized}
    end
  end

  @doc """
  Deletes a membership if the user has appropriate permissions.
  """
  @spec delete_membership(User.t(), Membership.t()) ::
          {:ok, Membership.t()} | {:error, Ecto.Changeset.t()} | {:error, :unauthorized}
  #
  def delete_membership(%User{id: user_id}, %Membership{org_id: org_id} = membership) do
    with {:ok, role} <- get_user_role(user_id, org_id),
         true <- MembershipRole.at_least?(role, :admin) do
      OrgRepo.delete(membership, org_id)
    else
      _ -> {:error, :unauthorized}
    end
  end

  @doc """
  Authorizes a user for a specific action in an organization.
  """
  @spec authorize_user(User.t(), integer(), MembershipRole.t()) :: :ok | {:error, :unauthorized}
  #
  def authorize_user(%User{id: user_id}, org_id, required_role) do
    with {:ok, role} <- get_user_role(user_id, org_id),
         true <- MembershipRole.at_least?(role, required_role) do
      :ok
    else
      _ -> {:error, :unauthorized}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking org changes.

  ## Examples

      iex> change_org(org)
      %Ecto.Changeset{data: %Org{}}

  """
  @spec change_org(Org.t(), map()) :: Ecto.Changeset.t()
  #
  def change_org(%Org{} = org, attrs \\ %{}) do
    Org.changeset(org, attrs)
  end

  @spec user_has_any_membership?(User.t()) :: boolean()
  #
  def user_has_any_membership?(%User{id: user_id}) do
    Repo.exists?(from m in Membership, where: m.user_id == ^user_id)
  end

  @spec get_user_primary_org(User.t()) :: Org.t() | nil
  #
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

  # Private functions

  @spec get_user_role(integer(), integer()) :: {:ok, MembershipRole.t()} | {:error, :not_found}
  #
  defp get_user_role(user_id, org_id) do
    case OrgRepo.get_by(Membership, [user_id: user_id], org_id) do
      %Membership{role: role} ->
        {:ok, role}

      nil ->
        {:error, :not_found}
    end
  end
end
