defmodule Horionos.Organizations.MembershipRole do
  @moduledoc """
  Defines and manages roles for organization memberships in Horionos.
  """

  @typedoc "Valid membership roles"
  @type t :: :owner | :admin | :member

  @roles [:owner, :admin, :member]
  @assignable_roles [:admin, :member]

  @doc "List of all valid roles"
  @spec all :: [t()]
  #
  def all, do: @roles

  @doc "List of roles that can be assigned"
  @spec assignable :: [t()]
  def assignable, do: @assignable_roles

  @doc "Validates if the given role is a valid membership role"
  @spec valid?(any()) :: boolean()
  #
  def valid?(role) when role in @roles, do: true
  def valid?(_), do: false
end
