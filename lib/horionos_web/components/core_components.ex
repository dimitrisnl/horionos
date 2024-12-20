defmodule HorionosWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.
  """
  use Phoenix.Component
  use Gettext, backend: HorionosWeb.Gettext

  import HorionosWeb.JSHelpers

  alias Phoenix.LiveView.JS

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div id={"#{@id}-bg"} class="bg-gray-50/90 fixed inset-0 transition-opacity" aria-hidden="true" />
      <div
        class="fixed top-0 right-0 left-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class="w-full max-w-2xl p-4 sm:p-6 lg:py-8">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="shadow-gray-700/10 ring-gray-700/10 relative hidden rounded-lg bg-white p-8 shadow-lg ring-1 transition"
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="-m-3 flex-none p-3 opacity-20 hover:opacity-40"
                  aria-label={gettext("close")}
                >
                  <.icon name="hero-x-mark-solid" class="h-5 w-5" />
                </button>
              </div>
              <div id={"#{@id}-content"}>
                {render_slot(@inner_block)}
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a header with title.
  """
  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions
  slot :nav

  def header(assigns) do
    ~H"""
    <header class="mx-auto mb-12 max-w-6xl space-y-5 border-b border-gray-100 pb-6" class={[@class]}>
      <div class="flex items-start justify-between">
        <div class="space-y-4">
          <h1 class="text-2xl/8 font-semibold text-gray-950 dark:text-white sm:text-xl/8">
            {render_slot(@inner_block)}
          </h1>
          <h2 :if={@subtitle != []} class="text-base/6 text-gray-600 dark:text-zinc-400 sm:text-md/6">
            {render_slot(@subtitle)}
          </h2>
        </div>
        <div :if={@subtitle == []}></div>

        <div :if={@actions != []}>
          {render_slot(@actions)}
        </div>
      </div>

      <div :if={@nav != []}>
        {render_slot(@nav)}
      </div>
    </header>
    """
  end

  def body(assigns) do
    ~H"""
    <div class="mx-auto mt-4 max-w-6xl">
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id"><%= user.id %></:col>
        <:col :let={user} label="username"><%= user.username %></:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-y-auto sm:overflow-visible">
      <table class="w-full">
        <thead class="text-left text-sm leading-6 text-gray-500">
          <tr>
            <th :for={col <- @col} class="px-4 py-0 pb-4 font-normal">{col[:label]}</th>
            <th :if={@action != []} class="relative px-4 py-0 pb-4">
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
          class="relative divide-y divide-gray-100 border-t border-gray-100 text-sm leading-6 text-gray-700"
        >
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="group hover:bg-gray-50">
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={["relative rounded-lg p-0 px-4", @row_click && "hover:cursor-pointer"]}
            >
              <div class="relative block truncate py-4">
                <span class="absolute -inset-y-px right-0 -left-4 group-hover:bg-gray-50 sm:rounded-l-xl" />
                <span class={["relative", i == 0 && "font-semibold text-gray-900"]}>
                  {render_slot(col, @row_item.(row))}
                </span>
              </div>
            </td>
            <td :if={@action != []} class="relative px-4">
              <div class="relative whitespace-nowrap py-4 text-right text-sm font-medium">
                <span class="absolute -inset-y-px -right-4 left-0 group-hover:bg-gray-50 sm:rounded-r-xl" />
                <span
                  :for={action <- @action}
                  class="relative ml-4 font-medium leading-6 text-gray-800 hover:text-gray-700"
                >
                  {render_slot(action, @row_item.(row))}
                </span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title"><%= @post.title %></:item>
        <:item title="Views"><%= @post.views %></:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <div class="mt-14">
      <dl class="divide-y divide-gray-100">
        <div :for={item <- @item} class="px-4 py-6 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-0">
          <dt class="truncate text-sm font-medium leading-6 text-gray-900">{item.title}</dt>
          <dd class="mt-1 break-words text-sm leading-6 text-gray-700 sm:col-span-2 sm:mt-0">
            {render_slot(item)}
          </dd>
        </div>
      </dl>
    </div>
    """
  end

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/posts"}>Back to posts</.back>
  """
  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <div>
      <.link
        navigate={@navigate}
        class="hover:text-gray-700 space-x-2 flex items-center hover:underline underline-offset-4"
      >
        <.icon name="hero-arrow-uturn-left-micro" class="h-4 w-4" />
        <div>
          {render_slot(@inner_block)}
        </div>
      </.link>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil
  attr :id, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span id={@id} class={[@name, @class]} />
    """
  end

  ## JS Commands
  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(HorionosWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(HorionosWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :text, :string, required: true
  attr :active, :boolean, default: false

  def nav_link(assigns) do
    ~H"""
    <.link
      href={@href}
      class={[
        "group flex w-full items-center gap-3 rounded-lg px-2 py-2.5 text-left text-base/6 font-medium sm:py-2 sm:text-sm/5",
        @active &&
          [
            "bg-gray-900/5 dark:bg-white/10",
            "text-gray-950 dark:text-white"
          ],
        !@active &&
          [
            "text-gray-700 hover:text-gray-950 dark:text-gray-400 dark:hover:text-white",
            "hover:bg-gray-950/5 active:bg-gray-950/5 dark:hover:bg-white/5 dark:active:bg-white/5"
          ]
      ]}
    >
      <.icon
        name={@icon}
        class={
           "shrink-0 size-5 " <>
           if @active do
             "text-gray-950 dark:text-white"
           else
             "text-gray-700 group-hover:text-gray-950 group-active:text-gray-950 dark:text-gray-400 dark:group-hover:text-white dark:group-active:text-white"
           end
         }
      />
      <span class="truncate">{@text}</span>
    </.link>
    """
  end

  @doc """
  Renders a brand icon.
  """

  attr :variant, :string, default: "large"

  def brand_icon(assigns) do
    ~H"""
    <div class="border-brand/50 rounded-full border border-dotted p-0.5">
      <div class="border-brand/50 rounded-full border border-dotted p-0.5">
        <div class={[
          "from-brand rounded-full bg-gradient-to-r to-red-100",
          @variant == "large" && "h-7 w-7",
          @variant == "small" && "h-5 w-5"
        ]}>
        </div>
      </div>
    </div>
    """
  end

  @doc """
    Renders the layout for the guest view.
    Login, Registration, etc
  """

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :inner_block, required: true

  def guest_view(assigns) do
    ~H"""
    <div class="flex flex-col justify-center py-4 sm:px-6 lg:px-8">
      <div class="sm:mx-auto sm:w-full sm:max-w-md">
        <h2 class="mt-6 text-center text-2xl font-bold leading-9 tracking-tight text-gray-900">
          {@title}
        </h2>
        <p class="mt-1 text-center text-base text-gray-600">
          {@subtitle}
        </p>
      </div>

      <div class="mt-10 sm:max-w-[480px] sm:mx-auto sm:w-full">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a card component.
  """

  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div class="bg-white px-6 py-12 shadow sm:rounded-lg sm:px-12">
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :active_tab, :atom, required: true
  attr :tabs, :list, required: true

  def nav(assigns) do
    ~H"""
    <nav class="relative -bottom-px -mb-6 flex flex-row space-y-0">
      <%= for tab <- @tabs do %>
        <.nav_item href={tab.href} icon={tab.icon} label={tab.label} active?={@active_tab == tab.id} />
      <% end %>
    </nav>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :active?, :boolean, required: true

  defp nav_item(assigns) do
    ~H"""
    <a
      href={@href}
      class={[
        "flex items-center space-x-1.5 rounded-t-xl border border-b-0 border-b border-transparent border-b-transparent px-4 py-2.5 text-sm font-medium",
        "text-gray-400 hover:text-gray-700",
        @active? && "!border-gray-200 text-gray-900"
      ]}
    >
      <.icon name={@icon} class="size-5" />
      <div>{@label}</div>
    </a>
    """
  end

  @doc """
  Renders a local time element.
  """
  attr :date, :string, required: true
  attr :id, :string

  def local_time(assigns) do
    ~H"""
    <time phx-hook="LocalTime" id={@id} class="invisible">{@date}</time>
    """
  end
end
