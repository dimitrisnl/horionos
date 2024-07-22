defmodule HorionosWeb.OrgSessionController do
  alias Horionos.Orgs
  use HorionosWeb, :controller
  require Logger

  def update(conn, %{"org_id" => org_id}) do
    current_org_id = get_session(conn, :current_org_id)
    current_user = conn.assigns.current_user

    with {:ok, next_org_id} <- validate_org_id(org_id),
         :ok <- check_org_change(current_org_id, next_org_id),
         {:ok, org} <- Orgs.get_org(current_user, next_org_id) do
      conn
      |> configure_session(renew: true)
      |> put_session(:current_org_id, next_org_id)
      |> put_flash(:info, "Switched to #{org.title}")
      |> redirect(to: "/")
    else
      {:error, :invalid_org_id} ->
        conn
        |> put_flash(:error, "Invalid organization selected")
        |> redirect(to: "/")

      {:error, :no_change} ->
        conn
        |> put_flash(:info, "You are already viewing this organization")
        |> redirect(to: "/")

      {:error, :unauthorized} ->
        Logger.error("User #{current_user.id} tried to switch to org #{org_id} without access")

        conn
        |> put_flash(:error, "You do not have access to this organization")
        |> redirect(to: "/")

      _ ->
        Logger.error("An unexpected error occurred while switching organizations.")

        conn
        |> put_flash(:error, "An unexpected error occurred.")
        |> redirect(to: "/")
    end
  end

  defp validate_org_id(org_id) when is_binary(org_id) do
    case Integer.parse(org_id) do
      {id, ""} -> {:ok, id}
      _ -> {:error, :invalid_org_id}
    end
  end

  defp validate_org_id(org_id) when is_integer(org_id), do: {:ok, org_id}

  defp validate_org_id(_), do: {:error, :invalid_org_id}

  defp check_org_change(current_org_id, next_org_id) when current_org_id == next_org_id,
    do: {:error, :no_change}

  defp check_org_change(_, _), do: :ok
end
