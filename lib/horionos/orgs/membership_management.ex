defmodule Horionos.Organizations.MembershipManagement do
  @moduledoc """
  This module provides functions for managing memberships.
  """
  import Ecto.Query

  alias Horionos.Accounts.User
  alias Horionos.OrganizationRepo
  alias Horionos.Organizations.Membership
  alias Horionos.Organizations.MembershipRole
  alias Horionos.Organizations.Organization
  alias Horionos.Repo

  @doc """
  Lists memberships for a given organization.
  """
  @spec list_organization_memberships(Organization.t()) :: {:ok, [Membership.t()]}
  def list_organization_memberships(%Organization{id: organization_id}) do
    memberships =
      Membership
      |> where([m], m.organization_id == ^organization_id)
      |> preload(:user)
      |> Repo.all()

    {:ok, memberships}
  end

  @doc """
  Lists memberships for a given user.
  """
  @spec list_user_memberships(User.t()) :: {:ok, [Membership.t()]}
  def list_user_memberships(%User{id: user_id}) do
    memberships =
      Membership
      |> where([m], m.user_id == ^user_id)
      |> preload(:organization)
      |> Repo.all()

    {:ok, memberships}
  end

  @doc """
  Creates a membership.
  """
  @spec create_membership(map()) :: {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}
  def create_membership(attrs) do
    if MembershipRole.valid?(attrs.role) && attrs.role in MembershipRole.assignable() do
      %Membership{}
      |> Membership.changeset(attrs)
      |> OrganizationRepo.insert(attrs.organization_id)
    else
      {:error, :invalid_role}
    end
  end

  @doc """
  Updates a membership.
  """
  @spec update_membership(Membership.t(), map()) ::
          {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}
  def update_membership(%Membership{organization_id: organization_id} = membership, attrs) do
    membership
    |> Membership.changeset(attrs)
    |> OrganizationRepo.update(organization_id)
  end

  @doc """
  Deletes a membership.
  """
  @spec delete_membership(Membership.t()) ::
          {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}
  def delete_membership(%Membership{organization_id: organization_id} = membership) do
    OrganizationRepo.delete(membership, organization_id)
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
  @spec user_in_organization?(Organization.t(), String.t()) :: boolean()
  #
  def user_in_organization?(%Organization{id: organization_id}, email) do
    Repo.exists?(
      from m in Membership,
        join: u in User,
        on: m.user_id == u.id,
        where: m.organization_id == ^organization_id and u.email == ^email
    )
  end

  @doc """
  Gets the user's role in an organization.
  """
  @spec get_user_role(User.t(), Organization.t()) ::
          {:ok, MembershipRole.t()} | {:error, :not_found}
  def get_user_role(%User{id: user_id}, %Organization{id: organization_id}) do
    case Repo.one(
           from m in Membership,
             where: m.user_id == ^user_id and m.organization_id == ^organization_id,
             select: m.role
         ) do
      nil -> {:error, :not_found}
      role -> {:ok, role}
    end
  end
end
