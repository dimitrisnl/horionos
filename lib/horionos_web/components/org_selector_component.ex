defmodule HorionosWeb.OrgSelectorComponent do
  @moduledoc """
  Organization selector
  """
  use HorionosWeb, :live_component

  def render(assigns) do
    ~H"""
    <ul role="list" class="py-1">
      <%= for org <- @orgs do %>
        <li>
          <.form for={%{}} method="post" action={~p"/org/select"}>
            <button
              disabled={org.id == @current_org.id}
              type="submit"
              class="flex w-full items-center gap-x-3 px-2 py-2 text-sm font-semibold leading-6 text-gray-700 hover:bg-gray-50 hover:text-blue-600"
            >
              <span class="text-[0.625rem] flex h-6 w-6 shrink-0 items-center justify-center rounded-lg border border-gray-200 bg-white font-bold text-gray-500 group-hover:border-blue-600 group-hover:text-blue-600">
                <%= String.first(org.title) %>
              </span>
              <span class="truncate"><%= org.title %></span>
              <%= if org.id == @current_org.id do %>
                <.icon name="hero-check-micro" class="ml-auto h-5 w-5 text-blue-600" />
              <% end %>
            </button>
            <input type="hidden" name="org_id" value={org.id} />
          </.form>
        </li>
      <% end %>
      <hr class="my-1 bg-gray-100" />
      <li>
        <.link
          href={~p"/orgs/new"}
          class="flex items-center gap-x-3 px-2 py-2 text-sm font-semibold leading-6 text-gray-700 hover:bg-gray-50 hover:text-blue-600"
        >
          <span class="text-[0.625rem] flex h-6 w-6 shrink-0 items-center justify-center rounded-lg border border-blue-100 bg-blue-50 font-bold text-gray-500 group-hover:border-blue-600 group-hover:text-blue-600">
            <.icon name="hero-plus-micro" class="text-blue-600" />
          </span>
          <div class="truncate">New organization</div>
        </.link>
      </li>
    </ul>
    """
  end
end
