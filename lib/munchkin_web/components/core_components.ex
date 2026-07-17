defmodule MunchkinWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: MunchkinWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href type navigate patch method download name value disabled)
  attr :class, :string
  attr :variant, :string, values: ~w(primary info error warning plain)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{
      "primary" => "btn-primary",
      "plain" => "btn-outline",
      "info" => "btn-info",
      "error" => "btn-error",
      "warning" => "btn-warning",
      nil => "btn-primary btn-soft"
    }

    assigns =
      assign_new(assigns, :class, fn ->
        ["btn", Map.fetch!(variants, assigns[:variant])]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  attr :value, :string, required: true
  attr :text, :string

  def tooltip(assigns) do
    assigns = assign_new(assigns, :text, fn -> gettext("Hover Me") end)

    ~H"""
    <div :if={Map.get(assigns, :value)} class="tooltip" data-tip={@value}>
      <button class="btn">{@text}</button>
    </div>
    """
  end

  attr :value, :string, required: true

  def infotip(assigns) do
    ~H"""
    <div :if={Map.get(assigns, :value)} class="tooltip tooltip-right" data-tip={@value}>
      <.icon name="hero-information-circle" />
    </div>
    """
  end

  attr :text, :string, required: true
  attr :id, :string
  attr :required, :boolean, default: false

  def label(assigns) do
    ~H"""
    <label for={@id}>
      <span>{@text}</span>
      <span :if={@required} class="text-red-600">*</span>
    </label>
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
  attr :info, :string, default: nil
  attr :required, :boolean, default: false
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :string, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :string, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> assign(:id, fn -> if assigns.name, do: field.name, else: field.id end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <fieldset class="fieldset mb-2">
      <label>
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <span class="label">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={@class || "checkbox checkbox-sm"}
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <fieldset class="fieldset mb-2">
      <legend class="fieldset-legend">
        <.label id={@id} text={@label} required={@required} />
        <.infotip :if={@info} value={@info} />
      </legend>
      <select
        id={@id}
        name={@name}
        class={[@class || "w-full select", @errors != [] && (@error_class || "select-error")]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || "w-full textarea",
            @errors != [] && (@error_class || "textarea-error")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(%{name: name} = assigns) do
    assigns =
      case Map.get(assigns, :id) do
        id when is_bitstring(id) -> assigns
        _ -> Map.put(assigns, :id, name)
      end

    ~H"""
    <fieldset class="fieldset mb-2">
      <legend :if={@label} class="fieldset-legend">
        <.label id={@id} text={@label} required={@required} />
        <.infotip :if={@info} value={@info} />
      </legend>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          @class || "w-full input",
          @errors != [] && (@error_class || "input-error")
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
      <.icon name="hero-exclamation-circle" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-base-content/70">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
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
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}>
            <span class="sr-only">{gettext("Actions")}</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
    attr :header_class, :string
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li
        :for={item <- @item}
        class="p-3 border-t first:border-t-0 border-base-content/20"
      >
        <div class="list-col-grow">
          <div class={["font-bold", Map.get(item, :header_class)]}>{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
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
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
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
      Gettext.dngettext(MunchkinWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(MunchkinWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  attr :title, :string
  attr :subtitle, :string
  attr :image, :string

  slot :inner_block,
    required: true,
    doc: "the optional inner block that renders the flash message"

  slot :action
  slot :header_action

  def card(assigns) do
    ~H"""
    <div class="card bg-base-200 w-full shadow-sm mt-4 first:mt-0">
      <figure :if={Map.get(assigns, :image)}>
        <img src={@image} />
      </figure>
      <div class="card-body">
        <div class="flex items-center justify-between border-b border-base-content/60 pb-4">
          <div>
            <h2 :if={Map.get(assigns, :title)} class="card-title">{@title}</h2>
            <span :if={Map.get(assigns, :subtitle)} class="text-sm italic">{@subtitle}</span>
          </div>
          <div :if={@header_action != []}>
            <%= for action <- @header_action do %>
              {render_slot(action)}
            <% end %>
          </div>
        </div>
        <div class="mt-2">
          {render_slot(@inner_block)}
        </div>
        <div :if={@action != []} class="card-actions justify-end">
          <%= for action <- @action do %>
            {render_slot(action)}
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  slot :item, required: true do
    attr :title, :string
    attr :class, :string
    attr :background, :string
    attr :value, :string, required: true
    attr :icon, :string
    attr :description, :string
    attr :link, :string
    attr :action, :string
  end

  def stats(assigns) do
    assigns =
      case length(assigns.item) do
        1 -> assign(assigns, :grid_class, "grid-cols-1")
        2 -> assign(assigns, :grid_class, "grid-cols-2")
        3 -> assign(assigns, :grid_class, "grid-cols-3")
        4 -> assign(assigns, :grid_class, "grid-cols-4")
        _ -> assign(assigns, :grid_class, "grid-cols-5")
      end

    ~H"""
    <div class={["shadow w-full grid gap-4", @grid_class]}>
      <div
        :for={item <- @item}
        class={[
          "flex-auto rounded-sm px-2 py-1 flex items-center min-w-64",
          Map.get(item, :action, "") != "" && "cursor-pointer",
          Map.get(item, :link, "") != "" && "cursor-pointer",
          Map.get(item, :background, "")
        ]}
      >
        <.stat_item_with_action
          :if={Map.get(item, :action)}
          action={Map.get(item, :action)}
          title={Map.get(item, :title)}
          class={Map.get(item, :class)}
          value={Map.get(item, :value)}
          icon={Map.get(item, :icon)}
          description={Map.get(item, :description)}
          link={Map.get(item, :link)}
        />
        <.stat_item
          :if={is_nil(Map.get(item, :action))}
          title={Map.get(item, :title)}
          class={Map.get(item, :class)}
          value={Map.get(item, :value)}
          icon={Map.get(item, :icon)}
          description={Map.get(item, :description)}
          link={Map.get(item, :link)}
        />
      </div>
    </div>
    """
  end

  attr :class, :string
  attr :title, :string
  attr :value, :string, required: true
  attr :link, :string
  attr :description, :string
  attr :icon, :string
  attr :action, :string, required: true

  defp stat_item_with_action(assigns) do
    ~H"""
    <div class="w-full flex flex-row items-center" phx-click={@action}>
      <div class="flex flex-col flex-auto px-4">
        <div class={["text-sm text-gray-200", @class]}>
          <.icon :if={@icon} name={@icon} />
        </div>
        <div class="stat-title mb-2 capitalize">{@title}</div>
        <div class={["text-4xl font-bold", Map.get(assigns, :class, "text-white")]}>
          {@value}
        </div>
        <div class="text-sm text-gray-300 mt-2">{@description}</div>
      </div>
      <div>
        <.icon name="hero-chevron-right" class="size-5" />
      </div>
    </div>
    """
  end

  attr :class, :string
  attr :title, :string
  attr :value, :string, required: true
  attr :link, :string
  attr :description, :string
  attr :icon, :string

  defp stat_item(assigns) do
    ~H"""
    <div class="w-full flex flex-row items-center">
      <div class="flex flex-col flex-auto px-4">
        <div class={["text-sm text-gray-200", @class]}>
          <.icon :if={@icon} name={@icon} />
        </div>
        <div class="stat-title mb-2 capitalize">{@title}</div>
        <div class={["text-4xl font-bold", Map.get(assigns, :class, "text-white")]}>
          {@value}
        </div>
        <div class="text-sm text-gray-300 mt-2">{@description}</div>
      </div>
      <div :if={Map.get(assigns, :link)}>
        <.link href={@link}>
          <.icon name="hero-chevron-right" class="size-5" />
        </.link>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :description, :string

  def title(assigns) do
    ~H"""
    <div class="w-full flex flex-col px-4 py-2 border-1 rounded border-neutral">
      <h1 class="text-2xl text-neutral-content font-bold">{@title}</h1>
      <div :if={Map.get(assigns, :description)} class="mt-2 text-neutral-content">{@description}</div>
    </div>
    """
  end

  attr :text, :string
  attr :size, :string, values: ~w(xs sm md lg xl)
  attr :type, :string, values: ~w(soft outline dash normal)
  attr :variant, :string, values: ~w(primary info error warning plain success)
  slot :inner_block

  def badge(assigns) do
    assigns = badge_assigns(assigns)

    ~H"""
    <div class={["badge", @size, @type, @variant]}>
      <.icon :if={Map.get(assigns, :icon)} name={@icon} />
      <span :if={Map.get(assigns, :text)}>{@text}</span>
      <div :if={@inner_block != []} class="w-full">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  defp badge_assigns(assigns) do
    badge_size(assigns)
    |> badge_type()
    |> badge_variant()
  end

  defp badge_size(assigns) do
    case Map.get(assigns, :size) do
      "xs" -> "badge-xs"
      "sm" -> "badge-sm"
      "lg" -> "badge-lg"
      "xl" -> "badge-xl"
      _ -> "badge-md"
    end
    |> then(&assign(assigns, :size, &1))
  end

  defp badge_type(assigns) do
    case Map.get(assigns, :type) do
      "soft" -> "badge-soft"
      "outline" -> "badge-outline"
      "dash" -> "badge-dash"
      _ -> ""
    end
    |> then(&assign(assigns, :type, &1))
  end

  defp badge_variant(assigns) do
    case Map.get(assigns, :variant) do
      "primary" -> "badge-primary"
      "info" -> "badge-info"
      "error" -> "badge-error"
      "warning" -> "badge-warning"
      "success" -> "badge-success"
      _ -> "badge-neutral"
    end
    |> then(&assign(assigns, :variant, &1))
  end

  attr :status, :string, values: ~w(pending ongoing queue executed)

  def transaction_status_badge(%{status: status} = assigns) do
    assigns = assign(assigns, :status, String.downcase(status))

    ~H"""
    <div>
      <.transaction_ongoing_badge :if={@status == "ongoing"} />
      <.transaction_pending_badge :if={@status == "pending"} />
      <.transaction_queue_badge :if={@status == "queue"} />
      <.transaction_executed_badge :if={@status == "executed"} />
    </div>
    """
  end

  attr :with_text, :boolean, default: false
  attr :class, :string, default: ""

  def transaction_ongoing_badge(assigns) do
    ~H"""
    <div class={["flex", @class != "" && @class]}>
      <.badge text="O" variant="warning" />
      <span :if={@with_text} class="ml-2">{gettext("Ongoing")}</span>
    </div>
    """
  end

  attr :with_text, :boolean, default: false
  attr :class, :string, default: ""

  def transaction_pending_badge(assigns) do
    ~H"""
    <div class={["flex", @class != "" && @class]}>
      <.badge text="P" />
      <span :if={@with_text} class="ml-2">{gettext("Pending")}</span>
    </div>
    """
  end

  attr :with_text, :boolean, default: false
  attr :class, :string, default: ""

  def transaction_executed_badge(assigns) do
    ~H"""
    <div class={["flex", @class != "" && @class]}>
      <.badge text="E" variant="primary" />
      <span :if={@with_text} class="ml-2">{gettext("Executed")}</span>
    </div>
    """
  end

  attr :with_text, :boolean, default: false
  attr :class, :string, default: ""

  def transaction_queue_badge(assigns) do
    ~H"""
    <div class={["flex", @class != "" && @class]}>
      <.badge text="Q" variant="info" />
      <span :if={@with_text} class="ml-2">{gettext("Queue")}</span>
    </div>
    """
  end

  def transaction_statuses(assigns) do
    ~H"""
    <div class="w-full flex my-2">
      <.transaction_executed_badge with_text={true} class="last-child:mr-0 mr-2" />
      <.transaction_ongoing_badge with_text={true} class="last-child:mr-0 mr-2" />
      <.transaction_queue_badge with_text={true} class="last-child:mr-0 mr-2" />
      <.transaction_pending_badge with_text={true} class="last-child:mr-0 mr-2" />
    </div>
    """
  end

  attr :type, :string, values: ~w(buy sell)

  def transaction_type_badge(%{type: type} = assigns) do
    assigns = assign(assigns, :type, String.downcase(type))

    ~H"""
    <div class="w-full">
      <.badge
        :if={@type == "buy"}
        text={gettext("Buy")}
        variant="success"
      />
      <.badge
        :if={@type == "sell"}
        text={gettext("Sell")}
        variant="error"
      />
    </div>
    """
  end

  attr :current, :integer, required: true
  attr :action, :string, required: true
  attr :href, :string
  attr :max, :integer, default: 5
  attr :type, :string, default: "button"

  def paginate(assigns) do
    ~H"""
    <div class="join">
      <button
        :for={i <- 1..@max}
        :if={@type == "button"}
        type="button"
        class={["join-item btn", @current == i && "btn-primary"]}
        phx-click={@action}
        phx-value-page={i}
      >
        {i}
      </button>
      <button
        :for={i <- 1..@max}
        :if={@type == "link"}
        type="button"
        class={["join-item btn", @current == i && "btn-primary"]}
      >
        <.link href={"#{@href}?page=#{i}"}>{i}</.link>
      </button>
    </div>
    """
  end

  attr :value, :float, required: true
  attr :type, :atom, default: :long

  def pnl_block(assigns) do
    assigns =
      assign(
        assigns,
        :format,
        Munchkin.Cldr.Number.to_string!(assigns.value,
          format: assigns.type
        )
      )

    ~H"""
    <div class="flex ml-2">
      <div :if={@value > 0} class="text-success">
        <span>(</span>
        <.icon name="hero-plus" />
        <span>{@format}</span>
        <span>)</span>
      </div>

      <div :if={@value < 0} class="text-danger">
        <span>(</span>
        <.icon name="hero-minus" />
        <span>{@format}</span>
        <span>)</span>
      </div>
    </div>
    """
  end

  attr :message, :string, required: true
  attr :description, :string
  attr :style, :string, values: ~w(dot outline soft normal)
  attr :variant, :string, values: ~w(primary info error warning)
  attr :icon, :string

  def alert(assigns) do
    variants = %{
      "primary" => "alert-primary",
      "info" => "alert-info",
      "error" => "alert-error",
      "warning" => "alert-warning",
      nil => ""
    }

    styles = %{
      "dot" => "alert-dash",
      "outline" => "alert-outline",
      "soft" => "alert-soft",
      nil => ""
    }

    assigns =
      assign_new(assigns, :class, fn ->
        ["alert", Map.fetch!(variants, assigns[:variant]), Map.fetch!(styles, assigns[:style])]
      end)

    ~H"""
    <div role="alert" class={@class}>
      <.icon :if={Map.get(assigns, :icon)} name={@icon} />
      <div>
        <h3 class="font-bold">{@message}</h3>
        <span :if={Map.get(assigns, :description)}>{@description}</span>
      </div>
    </div>
    """
  end

  attr :data, :list, required: true
  attr :type, :atom, required: true
  attr :timeframe, :string, default: "yearly"
  attr :format, :atom, values: [:short, :standard], default: :standard

  slot :row, required: true do
    attr :key, :atom
  end

  def fundamental_table(assigns) do
    assigns =
      assign_new(assigns, :columns, fn ->
        get_fundamental_range(assigns.data, assigns.timeframe)
      end)

    ~H"""
    <div class="flex w-full mt-4">
      <div class="flex flex-col w-1/5">
        <div class="h-12">&nbsp;</div>
        <div :for={r <- @row} class="w-[160px] h-12 font-bold">{render_slot(r)}</div>
      </div>
      <div class="flex flex-col overflow-x-scroll w-full max-w-[2160px]">
        <div class={["flex h-12 items-center", (@format == :standard && "w-[2160px]") || "w-full"]}>
          <span
            :for={r <- @columns}
            class={[
              (@format == :standard && "w-[210px]") || "w-[130px]",
              "ml-2 font-bold text-center"
            ]}
          >
            {r}
          </span>
        </div>
        <div
          :for={f <- @row}
          class={["flex h-12 items-center", (@format == :standard && "w-[2160px]") || "w-full"]}
        >
          <div
            :for={r <- @columns}
            class={[
              "ml-2",
              (@format == :standard && "w-[210px] text-left") || "w-[130px] text-center"
            ]}
          >
            <span>{get_fundamental_item(@data, @type, r, f.key, @format)}</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp get_fundamental_item(data, type, period, item, format) do
    Enum.find(data, &Kernel.==(&1.period, period))
    |> Map.get(type, %{})
    |> Map.get(item)
    |> case do
      num when is_number(num) -> Munchkin.Cldr.Number.to_string!(num, format: format)
      _ -> Munchkin.Cldr.Number.to_string!(0, format: :short)
    end
  end

  defp get_fundamental_period(data), do: data.period

  defp get_fundamental_range(data, "quarterly") do
    data
    |> Enum.filter(&String.contains?(&1.period, "Q"))
    |> Enum.reduce([], fn d, acc ->
      case String.contains?(d.period, "Q") do
        true -> [d.period | acc]
        _ -> acc
      end
    end)
    |> Enum.sort(:desc)
  end

  defp get_fundamental_range(data, _) do
    data
    |> Enum.reduce([], fn d, acc ->
      case String.contains?(d.period, "FY") do
        true -> [d.period | acc]
        _ -> acc
      end
    end)
    |> Enum.sort(:desc)
  end
end
