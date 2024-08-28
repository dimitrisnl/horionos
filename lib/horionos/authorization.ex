defmodule Horionos.Authorization do
  @moduledoc """
  Provides authorization functionality
  """

  require Logger

  alias Horionos.Accounts.User
  alias Horionos.AdminNotifications
  alias Horionos.Orgs
  alias Horionos.Orgs.Org
  alias Horionos.Repo

  @type error :: :unauthorized | :invalid_resource | :role_not_found

  @permissions %{
    # Org permissions
    org_view: [:member, :admin, :owner],
    org_edit: [:admin, :owner],
    org_delete: [:owner],
    org_invite_members: [:admin, :owner],
    org_manage_members: [:admin, :owner],

    # Announcement permissions
    announcement_view: [:member, :admin, :owner],
    announcement_create: [:member, :admin, :owner],
    announcement_edit: [:member, :admin, :owner],
    announcement_delete: [:member, :admin, :owner]
  }

  @type permission ::
          :org_view
          | :org_edit
          | :org_delete
          | :org_invite_members
          | :org_manage_members
          | :announcement_view
          | :announcement_create
          | :announcement_edit
          | :announcement_delete

  @doc """
  Authorizes a user for a specific action on a resource.
  """
  @spec authorize(User.t(), resource :: struct(), permission()) ::
          :ok | {:error, error()}
  def authorize(user, resource, permission) do
    with {:ok, org} <- get_org_from_resource(resource),
         {:ok, role} <- Orgs.get_user_role(user, org),
         true <- has_permission?(role, permission) do
      :ok
    else
      {:error, :invalid_resource} = error ->
        log_authorization_failure(user, resource, permission, error)
        error

      {:error, :not_found} ->
        error = {:error, :unauthorized}
        log_authorization_failure(user, resource, permission, error)
        error

      false ->
        error = {:error, :unauthorized}
        log_authorization_failure(user, resource, permission, error)
        error
    end
  end

  # Private functions

  defp get_org_from_resource(resource) do
    case resource do
      %Org{} = org -> {:ok, org}
      %{org_id: org_id} -> {:ok, Repo.get(Org, org_id)}
      _ -> {:error, :invalid_resource}
    end
  end

  defp has_permission?(role, permission) do
    allowed_roles = @permissions[permission] || []
    role in allowed_roles
  end

  defp log_authorization_failure(user, resource, permission, error) do
    AdminNotifications.notify(:authorization_error, %{
      user: user,
      resource: resource,
      permission: permission,
      error: error
    })
  end
end
