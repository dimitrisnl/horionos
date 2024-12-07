defmodule Horionos.Memberships.Helpers.MembershipRole do
  @moduledoc """
  Defines and manages roles
  """

  @typedoc "Valid membership roles"
  @type t :: :owner | :admin | :member

  @roles [:owner, :admin, :member]
  @assignable_roles [:admin, :member]

  @spec all :: [t()]
  def all, do: @roles

  @spec assignable :: [t()]
  def assignable, do: @assignable_roles

  @spec valid?(any()) :: boolean()
  def valid?(role) when role in @roles, do: true
  def valid?(_), do: false
end
