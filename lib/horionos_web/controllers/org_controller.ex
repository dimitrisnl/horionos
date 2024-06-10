defmodule HorionosWeb.OrgController do
  use HorionosWeb, :controller

  alias Horionos.Orgs
  alias Horionos.Orgs.Org

  def index(conn, _params) do
    orgs = Orgs.list_orgs()
    render(conn, :index, orgs: orgs)
  end

  def new(conn, _params) do
    changeset = Orgs.change_org(%Org{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"org" => org_params}) do
    case Orgs.create_org(org_params) do
      {:ok, org} ->
        conn
        |> put_flash(:info, "Org created successfully.")
        |> redirect(to: ~p"/orgs/#{org}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    org = Orgs.get_org!(id)
    render(conn, :show, org: org)
  end

  def edit(conn, %{"id" => id}) do
    org = Orgs.get_org!(id)
    changeset = Orgs.change_org(org)
    render(conn, :edit, org: org, changeset: changeset)
  end

  def update(conn, %{"id" => id, "org" => org_params}) do
    org = Orgs.get_org!(id)

    case Orgs.update_org(org, org_params) do
      {:ok, org} ->
        conn
        |> put_flash(:info, "Org updated successfully.")
        |> redirect(to: ~p"/orgs/#{org}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, org: org, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    org = Orgs.get_org!(id)
    {:ok, _org} = Orgs.delete_org(org)

    conn
    |> put_flash(:info, "Org deleted successfully.")
    |> redirect(to: ~p"/orgs")
  end
end
