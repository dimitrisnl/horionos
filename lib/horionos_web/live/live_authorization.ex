defmodule HorionosWeb.LiveAuthorization do
  @moduledoc """
  Liveview authz
  """
  alias Horionos.Authorization

  defmacro __using__(_opts) do
    quote do
      import HorionosWeb.LiveAuthorization
    end
  end

  @doc """
  Authorizes a user for a specific action.
  """
  def authorize_user_action(socket, permission) do
    Authorization.authorize(
      socket.assigns.current_user,
      socket.assigns.current_organization,
      permission
    )
  end
end
