defmodule Horionos.Memberships.MembershipRole do
  @moduledoc false

  @owner :owner
  @admin :admin
  @member :member

  @roles [@owner, @admin, @member]

  def is_owner(role), do: role == @owner
  def is_admin(role), do: role == @admin
  def is_member(role), do: role == @member

  def is_valid_role(role), do: Enum.member?(@roles, role)
end
