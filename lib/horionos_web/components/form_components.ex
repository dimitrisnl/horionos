defmodule HorionosWeb.FormComponents do
  @moduledoc """
  Form components
  """
  use Phoenix.Component

  import HorionosWeb.CoreComponents

  alias Phoenix.HTML.Form
  alias Phoenix.LiveView.JS

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="Email"/>
        <.input field={@form[:username]} label="Username" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.simple_form>
  """
  attr :for, :any, required: true, doc: "the datastructure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="space-y-8">
        <%= render_slot(@inner_block, f) %>
        <div :for={action <- @actions} class="mt-2 flex items-center justify-between gap-6">
          <%= render_slot(action, f) %>
        </div>
      </div>
    </.form>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr :type, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)
  attr :variant, :string, default: nil, doc: "the variant of the button"

  slot :inner_block, required: true
  slot :left_icon, default: nil
  slot :right_icon, default: nil

  def button(%{variant: "destructive"} = assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "rounded-lg bg-rose-50 px-2.5 py-3 hover:bg-rose-200 phx-submit-loading:opacity-75",
        "flex items-center justify-center space-x-2 text-sm font-medium leading-none text-rose-600 active:text-rose-600/80",
        @class
      ]}
      {@rest}
    >
      <%= if @left_icon != [] do %>
        <div><%= render_slot(@left_icon) %></div>
      <% end %>
      <div><%= render_slot(@inner_block) %></div>
      <%= if @right_icon != [] do %>
        <div><%= render_slot(@right_icon) %></div>
      <% end %>
    </button>
    """
  end

  def button(%{variant: "secondary"} = assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "rounded-lg bg-gray-100 px-2.5 py-3 hover:bg-gray-200 phx-submit-loading:opacity-75",
        "flex items-center justify-center space-x-2 text-sm font-medium leading-none text-gray-950 active:text-gray-950/80",
        @class
      ]}
      {@rest}
    >
      <%= if @left_icon != [] do %>
        <div><%= render_slot(@left_icon) %></div>
      <% end %>
      <div><%= render_slot(@inner_block) %></div>
      <%= if @right_icon != [] do %>
        <div><%= render_slot(@right_icon) %></div>
      <% end %>
    </button>
    """
  end

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "rounded-lg bg-gray-900 px-2.5 py-3 hover:bg-gray-700 phx-submit-loading:opacity-75",
        "flex items-center justify-center space-x-2 text-sm font-medium leading-none text-white active:text-white/80",
        @class
      ]}
      {@rest}
    >
      <%= if @left_icon != [] do %>
        <div><%= render_slot(@left_icon) %></div>
      <% end %>
      <div><%= render_slot(@inner_block) %></div>
      <%= if @right_icon != [] do %>
        <div><%= render_slot(@right_icon) %></div>
      <% end %>
    </button>
    """
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               range search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  slot :inner_block

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div phx-feedback-for={@name}>
      <label class="flex items-center gap-4 text-sm leading-6 text-gray-600">
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="rounded border-gray-300 text-gray-900 focus:ring-0"
          {@rest}
        />
        <%= @label %>
      </label>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}><%= @label %></.label>
      <select
        id={@id}
        name={@name}
        class="mt-2 block w-full rounded-md border border-gray-300 bg-white shadow-sm focus:border-gray-400 focus:ring-0 sm:text-sm"
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
      </select>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <div class="flex justify-between">
        <.label for={@id}><%= @label %></.label>

        <.error :for={msg <- @errors}><%= msg %></.error>
      </div>
      <textarea
        id={@id}
        name={@name}
        class={[
          "mt-2 block w-full rounded-lg text-gray-900 focus:ring-0 sm:text-sm sm:leading-6",
          "min-h-[6rem] phx-no-feedback:border-gray-300 phx-no-feedback:focus:border-gray-400",
          @errors == [] && "border-gray-300 focus:border-gray-400",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
    </div>
    """
  end

  def input(%{type: "password"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <div class="flex justify-between">
        <.label for={@id}><%= @label %></.label>

        <.error :for={msg <- @errors}><%= msg %></.error>
      </div>
      <div class="relative mt-2">
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            "block w-full rounded-lg text-gray-900 focus:ring-0 sm:text-sm sm:leading-6",
            "pr-8 phx-no-feedback:border-gray-300 phx-no-feedback:focus:border-gray-400",
            @errors == [] && "border-gray-300 focus:border-gray-400",
            @errors != [] && "border-rose-400 focus:border-rose-400"
          ]}
          {@rest}
        />
        <button
          type="button"
          class="absolute inset-y-0 right-0 flex items-center px-3 text-gray-400 hover:text-gray-500"
          phx-click={
            JS.toggle_attribute({"type", "password", "text"}, to: "##{@id}")
            |> JS.toggle_class("hidden", to: "#show-icon-#{@id}")
            |> JS.toggle_class("hidden", to: "#hide-icon-#{@id}")
          }
        >
          <.icon name="hero-eye" class="size-4" id={"show-icon-#{@id}"} />
          <.icon name="hero-eye-slash" class="size-4 hidden" id={"hide-icon-#{@id}"} />
        </button>
      </div>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <div class="flex justify-between">
        <.label for={@id}><%= @label %></.label>

        <.error :for={msg <- @errors}><%= msg %></.error>
      </div>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "mt-2 block w-full rounded-lg text-gray-900 focus:ring-0 sm:text-sm sm:leading-6",
          "phx-no-feedback:border-gray-300 phx-no-feedback:focus:border-gray-400",
          @errors == [] && "border-gray-300 focus:border-gray-400",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      />
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-semibold leading-6 text-gray-800">
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <div class="flex gap-1.5 text-xs leading-6 text-rose-600 phx-no-feedback:hidden">
      <.icon name="hero-exclamation-circle" class="mt-0.5 h-5 w-5 flex-none" />
      <div class="first-letter:uppercase"><%= render_slot(@inner_block) %></div>
    </div>
    """
  end
end
