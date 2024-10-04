defmodule HorionosWeb.LiveResPipes do
  @moduledoc """
  A collection of functions to help express pipes when processing live view responses.
  """

  alias Phoenix.LiveView.Socket

  @type layout :: {module(), atom()}
  @type temporary_assigns :: keyword()

  @spec ok(Socket.t()) :: {:ok, Socket.t()}
  def ok(%Socket{} = socket), do: {:ok, socket}

  @spec ok(Socket.t(), layout: layout()) :: {:ok, Socket.t(), layout: layout()}
  def ok(%Socket{} = socket, layout: layout), do: {:ok, socket, layout: layout}

  @spec ok(Socket.t(), layout: layout(), temporary_assigns: temporary_assigns()) ::
          {:ok, Socket.t(), layout: layout(), temporary_assigns: temporary_assigns()}
  def ok(%Socket{} = socket, layout: layout, temporary_assigns: temp_assigns),
    do: {:ok, socket, layout: layout, temporary_assigns: temp_assigns}

  @spec ok(Socket.t(), temporary_assigns: temporary_assigns()) ::
          {:ok, Socket.t(), temporary_assigns: temporary_assigns()}
  def ok(%Socket{} = socket, temporary_assigns: temp_assigns),
    do: {:ok, socket, temporary_assigns: temp_assigns}

  @spec noreply(Socket.t()) :: {:noreply, Socket.t()}
  def noreply(%Socket{} = socket), do: {:noreply, socket}
end
