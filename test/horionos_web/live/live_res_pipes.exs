defmodule HorionosWeb.LiveResPipesTest do
  use ExUnit.Case, async: true
  alias HorionosWeb.LiveResPipes
  alias Phoenix.LiveView.Socket

  setup do
    socket = %Socket{}
    {:ok, socket: socket}
  end

  describe "ok/1" do
    test "returns {:ok, socket} tuple", %{socket: socket} do
      assert LiveResPipes.ok(socket) == {:ok, socket}
    end
  end

  describe "ok/2 with layout" do
    test "returns {:ok, socket, layout: layout} tuple", %{socket: socket} do
      layout = {HorionosWeb.Layouts, :app}
      assert LiveResPipes.ok(socket, layout: layout) == {:ok, socket, layout: layout}
    end
  end

  describe "ok/2 with temporary_assigns" do
    test "returns {:ok, socket, temporary_assigns: temp_assigns} tuple", %{socket: socket} do
      temp_assigns = [form: :some_form]

      assert LiveResPipes.ok(socket, temporary_assigns: temp_assigns) ==
               {:ok, socket, temporary_assigns: temp_assigns}
    end
  end

  describe "ok/3 with layout and temporary_assigns" do
    test "returns {:ok, socket, layout: layout, temporary_assigns: temp_assigns} tuple", %{
      socket: socket
    } do
      layout = {HorionosWeb.Layouts, :app}
      temp_assigns = [form: :some_form]

      assert LiveResPipes.ok(socket, layout: layout, temporary_assigns: temp_assigns) ==
               {:ok, socket, layout: layout, temporary_assigns: temp_assigns}
    end
  end

  describe "noreply/1" do
    test "returns {:noreply, socket} tuple", %{socket: socket} do
      assert LiveResPipes.noreply(socket) == {:noreply, socket}
    end
  end
end
