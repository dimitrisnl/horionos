defmodule HorionosWeb.AuthLive.UserLoginLive do
  use HorionosWeb, :live_view

  def render(assigns) do
    ~H"""
    <.guest_view title="Log in to your account" subtitle="Welcome back!">
      <.card>
        <.simple_form for={@form} id="login_form" action={~p"/users/log_in"} phx-update="ignore">
          <.input field={@form[:email]} type="email" label="Email" required />
          <.input field={@form[:password]} type="password" label="Password" required />

          <:actions>
            <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
            <.link href={~p"/users/reset_password"} class="text-sm font-semibold">
              Forgot your password?
            </.link>
          </:actions>
          <:actions>
            <.button phx-disable-with="Signing in..." class="w-full">
              Log in
              <:right_icon>
                <.icon name="hero-arrow-right-micro" />
              </:right_icon>
            </.button>
          </:actions>
        </.simple_form>
      </.card>

      <p class="mt-10 text-center text-sm text-gray-500">
        Don't have an account?
        <.link navigate={~p"/users/register"} class="font-semibold text-brand hover:underline">
          Sign up
        </.link>
      </p>
    </.guest_view>
    """
  end

  def mount(_params, _session, socket) do
    email = live_flash(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form),
     temporary_assigns: [form: form], layout: {HorionosWeb.Layouts, :guest}}
  end
end
