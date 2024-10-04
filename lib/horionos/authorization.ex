defmodule Horionos.Authorization do
  @moduledoc """
  Provides authorization functionality
  """

  alias Horionos.Accounts.User
  alias Horionos.AdminNotifications
  alias Horionos.Organizations
  alias Horionos.Organizations.Organization
  alias Horionos.Repo

  require Logger

  @type error :: :unauthorized | :invalid_resource | :role_not_found

  @permissions %{
    # Organization permissions
    organization_view: [:member, :admin, :owner],
    organization_edit: [:admin, :owner],
    organization_delete: [:owner],
    organization_invite_members: [:admin, :owner],
    organization_manage_members: [:admin, :owner],

    # Announcement permissions
    announcement_view: [:member, :admin, :owner],
    announcement_create: [:member, :admin, :owner],
    announcement_edit: [:member, :admin, :owner],
    announcement_delete: [:member, :admin, :owner]
  }

  @type permission ::
          :organization_view
          | :organization_edit
          | :organization_delete
          | :organization_invite_members
          | :organization_manage_members
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
    with {:ok, organization} <- get_organization_from_resource(resource),
         {:ok, role} <- Organizations.get_user_role(user, organization),
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

  def get_organization_from_resource(resource) do
    case resource do
      %Organization{} = organization -> {:ok, organization}
      %{organization_id: organization_id} -> {:ok, Repo.get(Organization, organization_id)}
      _ -> {:error, :invalid_resource}
    end
  end

  def has_permission?(role, permission) do
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
