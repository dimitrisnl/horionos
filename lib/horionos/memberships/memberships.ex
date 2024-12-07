defmodule Horionos.Memberships.Memberships do
  @moduledoc """
  Memberships context
  """
  import Ecto.Query

  alias Horionos.Accounts.Schemas.User
  alias Horionos.Memberships.Helpers.MembershipRole
  alias Horionos.Memberships.Schemas.Membership
  alias Horionos.Organizations.Schemas.Organization
  alias Horionos.Repo

  @spec list_organization_memberships(Organization.t()) :: {:ok, [Membership.t()]}
  def list_organization_memberships(%Organization{id: organization_id}) do
    memberships =
      Membership
      |> where([m], m.organization_id == ^organization_id)
      |> preload(:user)
      |> Repo.all()

    {:ok, memberships}
  end

  @spec list_user_memberships(User.t()) :: {:ok, [Membership.t()]}
  def list_user_memberships(%User{id: user_id}) do
    memberships =
      Membership
      |> where([m], m.user_id == ^user_id)
      |> preload(:organization)
      |> Repo.all()

    {:ok, memberships}
  end

  # Todo: Let changeset fail here
  @spec create_membership(map()) :: {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}
  def create_membership(attrs) do
    if MembershipRole.valid?(attrs.role) && attrs.role in MembershipRole.assignable() do
      attrs
      |> Membership.create_changeset()
      |> Repo.insert()
    else
      {:error, :invalid_role}
    end
  end

  @spec update_membership_role(Membership.t(), map()) ::
          {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}
  def update_membership_role(membership, attrs) do
    membership
    |> Membership.update_role_changeset(attrs)
    |> Repo.update()
  end

  @spec delete_membership(Membership.t()) ::
          {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}
  def delete_membership(%Membership{} = membership) do
    Repo.delete(membership)
  end

  @spec user_has_any_membership?(String.t()) :: boolean()
  def user_has_any_membership?(email) do
    Membership
    |> join(:inner, [m], u in User, on: m.user_id == u.id)
    |> where([_m, u], u.email == ^email)
    |> Repo.exists?()
  end

  @spec user_in_organization?(Organization.t(), String.t()) :: boolean()
  def user_in_organization?(%Organization{id: organization_id}, email) do
    Membership
    |> join(:inner, [m], u in User, on: m.user_id == u.id)
    |> where([m, u], m.organization_id == ^organization_id and u.email == ^email)
    |> Repo.exists?()
  end

  @spec get_user_role(User.t(), Organization.t()) ::
          {:ok, MembershipRole.t()} | {:error, :role_not_found}
  def get_user_role(%User{id: user_id}, %Organization{id: organization_id}) do
    Membership
    |> where([m], m.user_id == ^user_id and m.organization_id == ^organization_id)
    |> select([m], m.role)
    |> Repo.one()
    |> case do
      nil -> {:error, :role_not_found}
      role -> {:ok, role}
    end
  end

  # Todo: This is a temporary solution
  # This is not ideal
  # We should get the last-accessed organization which should be stored in the session/cookie/db
  @spec get_user_primary_organization(User.t()) :: Organization.t() | nil
  def get_user_primary_organization(%User{id: user_id}) do
    Organization
    |> join(:inner, [o], m in Membership, on: m.organization_id == o.id)
    |> where([_o, m], m.user_id == ^user_id)
    |> order_by([_o, m], asc: m.inserted_at)
    |> limit(1)
    |> Repo.one()
  end
end
