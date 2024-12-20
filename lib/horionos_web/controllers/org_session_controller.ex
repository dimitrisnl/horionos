defmodule HorionosWeb.OrganizationSessionController do
  use HorionosWeb, :controller

  alias Horionos.Memberships.Memberships
  alias Horionos.Organizations.Organizations
  alias Horionos.Organizations.Policies.OrganizationPolicy

  require Logger

  def update(conn, %{"organization_id" => organization_id}) do
    current_organization_id = get_session(conn, :current_organization_id)
    current_user = conn.assigns.current_user

    with {:ok, next_organization_id} <- validate_organization_id(organization_id),
         :ok <- organization_changed?(current_organization_id, next_organization_id),
         {:ok, organization} <- Organizations.get_organization(to_string(next_organization_id)),
         {:ok, role} <- Memberships.get_user_role(current_user, organization),
         {:ok} <- OrganizationPolicy.authorize(role, :view) do
      conn
      |> configure_session(renew: true)
      |> put_session(:current_organization_id, next_organization_id)
      |> put_flash(:info, "Switched to #{organization.title}")
      |> redirect(to: "/")
    else
      {:error, :invalid_organization_id} ->
        conn
        |> put_flash(:error, "Invalid organization selected")
        |> redirect(to: "/")

      {:error, :no_change} ->
        conn
        |> put_flash(:info, "You are already viewing this organization")
        |> redirect(to: "/")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Organization not found")
        |> redirect(to: "/")

      {:error, :role_not_found} ->
        Logger.error(
          "User #{current_user.id} tried to switch to organization #{organization_id} without access"
        )

        conn
        |> put_flash(:error, "Organization not found")
        |> redirect(to: "/")

      {:error, :unauthorized} ->
        Logger.error(
          "User #{current_user.id} tried to switch to organization #{organization_id} without access"
        )

        conn
        |> put_flash(:error, "Organization not found")
        |> redirect(to: "/")
    end
  end

  defp validate_organization_id(organization_id) when is_binary(organization_id) do
    case Integer.parse(organization_id) do
      {id, ""} -> {:ok, id}
      _ -> {:error, :invalid_organization_id}
    end
  end

  defp validate_organization_id(organization_id) when is_integer(organization_id),
    do: {:ok, organization_id}

  defp validate_organization_id(_), do: {:error, :invalid_organization_id}

  defp organization_changed?(current_organization_id, next_organization_id)
       when current_organization_id == next_organization_id,
       do: {:error, :no_change}

  defp organization_changed?(_, _), do: :ok
end
