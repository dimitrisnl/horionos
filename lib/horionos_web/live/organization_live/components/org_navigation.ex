defmodule HorionosWeb.Organization.Components.OrganizationNavigation do
  @moduledoc """
  A component to render the organization navigation.
  """
  use HorionosWeb, :html

  attr :title, :string, required: true
  attr :active_tab, :atom, required: true

  def organization_navigation(assigns) do
    ~H"""
    <.header>
      {@title}
      <:nav>
        <.nav
          active_tab={@active_tab}
          tabs={[
            %{
              id: :organization_details,
              href: ~p"/organization",
              icon: "hero-adjustments-horizontal",
              label: "Settings"
            },
            %{
              id: :organization_invitations,
              href: ~p"/organization/invitations",
              icon: "hero-envelope",
              label: "Invitations"
            }
          ]}
        />
      </:nav>
    </.header>
    """
  end
end
