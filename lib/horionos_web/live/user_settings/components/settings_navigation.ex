defmodule HorionosWeb.UserSettings.Components.SettingsNavigation do
  @moduledoc """
  A component to render the settings navigation.
  """
  use HorionosWeb, :html

  attr :title, :string, required: true
  attr :active_tab, :atom, required: true

  def settings_navigation(assigns) do
    ~H"""
    <.header>
      {@title}
      <:nav>
        <.nav
          active_tab={@active_tab}
          tabs={[
            %{
              id: :user_profile,
              href: ~p"/users/settings",
              icon: "hero-user-circle",
              label: "Settings"
            },
            %{
              id: :user_security,
              href: ~p"/users/settings/security",
              icon: "hero-lock-closed",
              label: "Security"
            }
          ]}
        />
      </:nav>
    </.header>
    """
  end
end
