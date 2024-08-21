defmodule Horionos.Orgs.MembershipManagement do
  @moduledoc """
  This module provides functions for managing memberships.
  """
  import Ecto.Query

  alias Horionos.Accounts.User
  alias Horionos.OrgRepo
  alias Horionos.Orgs.{Membership, MembershipRole, Org}
  alias Horionos.Repo

  @doc """
  Lists memberships for a given org.
  """
  @spec list_org_memberships(Org.t()) :: [Membership.t()]
  def list_org_memberships(%Org{id: org_id}) do
    Membership
    |> where([m], m.org_id == ^org_id)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Creates a membership.
  """
  @spec create_membership(map()) :: {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}
  def create_membership(attrs) do
    %Membership{}
    |> Membership.changeset(attrs)
    |> OrgRepo.insert(attrs.org_id)
  end

  @doc """
  Updates a membership.
  """
  @spec update_membership(Membership.t(), map()) ::
          {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}
  def update_membership(%Membership{org_id: org_id} = membership, attrs) do
    membership
    |> Membership.changeset(attrs)
    |> OrgRepo.update(org_id)
  end

  @doc """
  Deletes a membership.
  """
  @spec delete_membership(Membership.t()) ::
          {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}
  def delete_membership(%Membership{org_id: org_id} = membership) do
    OrgRepo.delete(membership, org_id)
  end

  @doc """
  Checks if a user has any membership in any organization.
  """
  @spec user_has_any_membership?(String.t()) :: boolean()
  #
  def user_has_any_membership?(email) when is_binary(email) do
    Repo.exists?(
      from m in Membership,
        join: u in User,
        on: m.user_id == u.id,
        where: u.email == ^email
    )
  end

  @doc """
  Checks if a user with the given email is already a member of the specified organization.
  """
  @spec user_in_org?(Org.t(), String.t()) :: boolean()
  #
  def user_in_org?(%Org{id: org_id}, email) do
    Repo.exists?(
      from m in Membership,
        join: u in User,
        on: m.user_id == u.id,
        where: m.org_id == ^org_id and u.email == ^email
    )
  end

  @doc """
  Gets the user's role in an organization.
  """
  @spec get_user_role(integer(), integer()) :: {:ok, MembershipRole.t()} | {:error, :not_found}
  def get_user_role(user_id, org_id) do
    case Repo.one(
           from m in Membership,
             where: m.user_id == ^user_id and m.org_id == ^org_id,
             select: m.role
         ) do
      nil -> {:error, :not_found}
      role -> {:ok, role}
    end
  end
end
