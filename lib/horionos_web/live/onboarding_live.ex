defmodule HorionosWeb.OnboardingLive do
  use HorionosWeb, :live_view

  alias Horionos.Orgs

  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-center py-4 sm:px-6 lg:px-8">
      <div class="sm:mx-auto sm:w-full sm:max-w-md">
        <h2 class="mt-6 text-center text-2xl font-bold leading-9 tracking-tight text-gray-900">
          Create Your Organization
        </h2>
        <p class="mt-1 text-center text-base text-gray-600">
          By creating an organization, you can invite your team members and start collaborating.
        </p>
      </div>

      <div class="mt-10 sm:max-w-[420px] sm:mx-auto sm:w-full">
        <.simple_form for={@form} id="org-form" phx-submit="save">
          <.input field={@form[:title]} type="text" placeholder="Organization Name" required />
          <:actions>
            <.button class="w-full" phx-disable-with="Creating...">Create Organization</.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    if socket.assigns[:current_org] do
      {:ok, push_redirect(socket, to: ~p"/")}
    else
      form = to_form(%{"title" => ""})
      {:ok, assign(socket, form: form), layout: {HorionosWeb.Layouts, :minimal}}
    end
  end

  def handle_event("save", %{"title" => title}, socket) do
    case Orgs.create_org(socket.assigns.current_user, %{title: title}) do
      {:ok, org} ->
        {:noreply,
         socket
         |> redirect(to: ~p"/?org_id=#{org.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
