defmodule HorionosWeb.PageController do
  use HorionosWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
