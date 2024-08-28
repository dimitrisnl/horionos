defmodule HorionosWeb.OrganizationSelectorComponent do
  @moduledoc """
  Organization selector
  """
  use HorionosWeb, :live_component

  def render(assigns) do
    ~H"""
    <ul role="list" class="py-1">
      <%= for membership <- @memberships do %>
        <li>
          <.form for={%{}} method="post" action={~p"/organization/select"}>
            <button
              disabled={membership.organization.id == @current_organization.id}
              type="submit"
              class="flex w-full items-center gap-x-3 px-2 py-2 text-sm font-semibold leading-6 text-gray-700 hover:bg-gray-50 hover:text-blue-600"
            >
              <span class="text-[0.625rem] flex h-6 w-6 shrink-0 items-center justify-center rounded-lg border border-gray-200 bg-white font-bold text-gray-500 group-hover:border-blue-600 group-hover:text-blue-600">
                <%= String.first(membership.organization.title) %>
              </span>
              <span class="truncate"><%= membership.organization.title %></span>
              <div class="ml-auto space-x-2">
                <span class="text-[0.625rem] inline-flex rounded-lg bg-blue-100 px-1 py-0.5 text-xs font-bold uppercase">
                  <%= membership.role %>
                </span>
                <%= if membership.organization.id == @current_organization.id do %>
                  <.icon name="hero-check-micro" class="h-4 w-4 text-blue-600 flex-shrink-0" />
                <% end %>
              </div>
            </button>
            <input type="hidden" name="organization_id" value={membership.organization.id} />
          </.form>
        </li>
      <% end %>
      <!--
      <hr class="my-1 bg-gray-100" />
      <li>
        <.link
          href={~p"/organization"}
          class="flex items-center gap-x-3 px-2 py-2 text-sm font-semibold leading-6 text-gray-700 hover:bg-gray-50 hover:text-blue-600"
        >
          <span class="text-[0.625rem] flex h-6 w-6 shrink-0 items-center justify-center rounded-lg border border-blue-100 bg-blue-50 font-bold text-gray-500 group-hover:border-blue-600 group-hover:text-blue-600">
            <.icon name="hero-plus-micro" class="text-blue-600" />
          </span>
          <div class="truncate">New organization</div>
        </.link>
      </li>
       -->
    </ul>
    """
  end
end
