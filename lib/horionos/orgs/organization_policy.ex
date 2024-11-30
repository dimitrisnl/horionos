defmodule Horionos.Organizations.OrganizationPolicy do
  @moduledoc """
  Authorization policies for Organizations
  """

  @type permission ::
          :view
          | :edit
          | :delete
          | :invite_members
          | :view_members
          | :manage_members
          | :view_invitations
  @type role :: :member | :admin | :owner
  @permissions %{
    view: [:member, :admin, :owner],
    edit: [:admin, :owner],
    delete: [:owner],
    view_invitations: [:admin, :owner],
    invite_members: [:admin, :owner],
    view_members: [:member, :admin, :owner],
    manage_members: [:admin, :owner]
  }

  @spec authorize(role(), permission()) :: {:ok} | {:error, :unauthorized}
  def authorize(role, permission) do
    if role in (@permissions[permission] || []) do
      {:ok}
    else
      {:error, :unauthorized}
    end
  end
end
