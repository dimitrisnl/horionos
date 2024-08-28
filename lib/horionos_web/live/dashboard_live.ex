defmodule HorionosWeb.DashboardLive do
  use HorionosWeb, :live_view

  def render(assigns) do
    ~H"""
    <.header>
      Welcome!
      <:subtitle>
        This is your dashboard for the
        <span class="font-medium">"<%= @current_organization.title %>"</span>
        organization
      </:subtitle>
    </.header>
    <div class="grid grid-cols-3 gap-8">
      <div class="h-[100px] flex flex-col justify-center space-y-3 rounded-xl bg-gray-100 p-4">
        <div class="h-3 w-1/2 rounded bg-gray-400" />
        <div class="h-3 w-1/3 rounded bg-gray-200" />
        <div class="h-3 w-3/5 rounded bg-gray-300" />
      </div>
      <div class="h-[100px] flex flex-col justify-center space-y-3 rounded-xl bg-gray-100 p-4">
        <div class="h-3 w-1/2 rounded bg-gray-200" />
        <div class="h-3 w-1/4 rounded bg-gray-300" />
        <div class="h-3 w-1/2 rounded bg-gray-400" />
      </div>
      <div class="h-[100px] flex flex-col justify-center space-y-3 rounded-xl bg-gray-100 p-4">
        <div class="h-3 w-1/4 rounded bg-gray-300" />
        <div class="h-3 w-1/3 rounded bg-gray-200" />
        <div class="h-3 w-3/5 rounded bg-gray-300" />
      </div>
      <div class="col-span-3 space-y-3 rounded-xl bg-gray-100 p-4">
        <div class="h-3 w-1/4 rounded bg-gray-300" />
        <div class="h-3 w-1/3 rounded bg-gray-200" />
        <div class="h-3 w-3/5 rounded bg-gray-300" />
        <div class="h-3 w-1/4 rounded bg-gray-300" />
        <div class="h-3 w-1/3 rounded bg-gray-200" />
        <div class="h-3 w-3/5 rounded bg-gray-300" />
        <div class="h-3 w-1/2 rounded bg-gray-200" />
        <div class="h-3 w-1/4 rounded bg-gray-300" />
        <div class="h-3 w-1/2 rounded bg-gray-200" />
        <div class="h-3 w-3/5 rounded bg-gray-300" />
        <div class="h-3 w-1/2 rounded bg-gray-400" />
        <div class="h-3 w-1/2 rounded bg-gray-300" />
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:current_email, user.email)

    {:ok, socket, layout: {HorionosWeb.Layouts, :dashboard}}
  end
end
