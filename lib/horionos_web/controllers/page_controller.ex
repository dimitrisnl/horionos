defmodule HorionosWeb.PageController do
  use HorionosWeb, :controller

  # alias Horionos.Memberships

  def home(conn, _params) do
    #user = conn.assigns.current_user
    # memberships = Memberships.list_memberships_by_user(user.id)

    render(conn, :home)
  end
end
