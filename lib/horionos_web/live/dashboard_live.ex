defmodule HorionosWeb.DashboardLive do
  use HorionosWeb, :live_view

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.header>
      Welcome!
      <:subtitle>
        This is your dashboard for the
        <span class="font-medium">"{@current_organization.title}"</span>
        organization
      </:subtitle>
    </.header>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    socket
    |> assign(:current_email, user.email)
    |> ok(layout: {HorionosWeb.Layouts, :dashboard})
  end
end
