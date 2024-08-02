defmodule HorionosWeb.DashboardLive do
  use HorionosWeb, :live_view
  alias Horionos.Orgs

  def render(assigns) do
    ~H"""
    <.header>
      Welcome!
      <:subtitle>
        This is your dashboard for the <span class="font-medium">"<%= @current_org.title %>"</span>
        organization
      </:subtitle>
      <:actions>
        <.button>
          <:left_icon>
            <.icon name="hero-sparkles-micro" />
          </:left_icon>
          This button does nothing
        </.button>
      </:actions>
    </.header>
    <div class="grid grid-cols-3 gap-8">
      <div class="h-[100px] flex flex-col justify-center space-y-3 rounded-xl bg-gradient-to-b from-gray-50 to-zinc-100 p-4">
        <div class="h-3 w-1/2 bg-gray-200" />
        <div class="h-3 w-1/3 bg-gray-200" />
        <div class="h-3 w-3/5 bg-gray-200" />
      </div>
      <div class="h-[100px] flex flex-col justify-center space-y-3 rounded-xl bg-gradient-to-b from-gray-50 to-zinc-100 p-4">
        <div class="h-3 w-1/2 bg-gray-200" />
        <div class="h-3 w-1/4 bg-gray-200" />
        <div class="h-3 w-1/2 bg-gray-200" />
      </div>
      <div class="h-[100px] flex flex-col justify-center space-y-3 rounded-xl bg-gradient-to-b from-gray-50 to-zinc-100 p-4">
        <div class="h-3 w-1/4 bg-gray-200" />
        <div class="h-3 w-1/3 bg-gray-200" />
        <div class="h-3 w-3/5 bg-gray-200" />
      </div>
      <div class="h-[300px] col-span-3 rounded-xl bg-gradient-to-b from-gray-50 to-zinc-100"></div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    orgs = Orgs.list_user_orgs(user)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:orgs, orgs)

    {:ok, socket, layout: {HorionosWeb.Layouts, :dashboard}}
  end
end
