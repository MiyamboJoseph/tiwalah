defmodule AppWeb.RecitationComponents do
  use Phoenix.Component

  import AppWeb.CoreComponents, only: [icon: 1]

  attr :assignment, :map, required: true
  slot :action
  slot :detail

  def assignment_card(assigns) do
    ~H"""
    <article class="rounded-2xl border border-emerald-900/10 bg-white p-5 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md dark:bg-base-200">
      <div class="flex items-start justify-between gap-4">
        <div>
          <p class="text-xs font-bold uppercase tracking-[0.18em] text-amber-700">
            Juz {@assignment.juz_number}
          </p>
          <h3 class="mt-1 text-lg font-semibold text-emerald-950 dark:text-emerald-100">
            {@assignment.title}
          </h3>
          <p class="mt-1 text-sm text-stone-600 dark:text-stone-300">
            {@assignment.surah_name}, ayah {@assignment.ayah_from}–{@assignment.ayah_to}
          </p>
        </div>
        <.status_badge status={@assignment.status} />
      </div>
      {render_slot(@detail)}
      <div class="mt-5 flex items-center justify-between border-t border-emerald-900/10 pt-4 text-sm text-stone-600 dark:text-stone-300">
        <span :if={@assignment.due_date}>
          Due {Calendar.strftime(@assignment.due_date, "%d %b %Y")}
        </span>
        <span :if={!@assignment.due_date}>Practice at your pace</span>
        {render_slot(@action)}
      </div>
    </article>
    """
  end

  attr :status, :atom, required: true

  def status_badge(assigns) do
    labels = %{
      assigned: "Assigned",
      submitted: "Awaiting review",
      reviewed: "Approved",
      repeat_required: "Repeat needed"
    }

    classes = %{
      assigned: "bg-sky-100 text-sky-800",
      submitted: "bg-amber-100 text-amber-900",
      reviewed: "bg-emerald-100 text-emerald-900",
      repeat_required: "bg-rose-100 text-rose-900"
    }

    assigns = assign(assigns, label: labels[assigns.status], class: classes[assigns.status])

    ~H"""
    <span class={[@class, "rounded-full px-3 py-1 text-xs font-semibold"]}>{@label}</span>
    """
  end

  attr :categories, :list, default: []
  attr :label, :string, default: nil

  def feedback_categories(assigns) do
    ~H"""
    <div :if={@categories != []} class="mt-3 flex flex-wrap gap-2">
      <p :if={@label} class="basis-full text-xs font-bold uppercase tracking-[0.14em] text-amber-700">
        {@label}
      </p>
      <span
        :for={category <- @categories}
        class="rounded-full bg-amber-100 px-2.5 py-1 text-xs font-semibold text-amber-900"
      >
        {category}
      </span>
    </div>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :categories, :list, required: true

  def correction_area_selector(assigns) do
    selected = List.wrap(assigns.field.value)
    assigns = assign(assigns, selected: selected)

    ~H"""
    <fieldset>
      <legend class="text-sm font-medium text-stone-700 dark:text-stone-200">
        Correction areas <span class="text-stone-400">(optional)</span>
      </legend>
      <p class="mt-1 text-xs text-stone-500 dark:text-stone-400">
        Select the areas the student should focus on next.
      </p>
      <div class="mt-3 grid gap-2 sm:grid-cols-2">
        <label
          :for={category <- @categories}
          for={"#{@field.id}-#{slug(category)}"}
          class={[
            "flex cursor-pointer items-center gap-3 rounded-xl border px-3 py-2.5 text-sm font-medium transition",
            if(category in @selected,
              do: "border-emerald-700 bg-emerald-50 text-emerald-950",
              else:
                "border-emerald-900/15 bg-white text-stone-700 hover:border-emerald-700/50 dark:bg-base-300 dark:text-stone-200"
            )
          ]}
        >
          <input
            id={"#{@field.id}-#{slug(category)}"}
            type="checkbox"
            name={"#{@field.name}[]"}
            value={category}
            checked={category in @selected}
            class="size-4 rounded border-stone-300 text-emerald-800 focus:ring-emerald-700"
          />
          {category}
        </label>
      </div>
    </fieldset>
    """
  end

  defp slug(value), do: value |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")

  attr :passage, :any, required: true
  attr :page, :integer, default: 1
  attr :per_page, :integer, default: 5
  attr :on_page_change, :string, default: nil
  attr :allow_show_all, :boolean, default: false
  attr :show_all, :boolean, default: false
  attr :on_show_all, :string, default: nil

  def quran_passage(assigns) do
    assigns = assign_passage_page(assigns)

    ~H"""
    <section
      :if={@passage == :loading}
      class="rounded-2xl border border-emerald-900/10 bg-emerald-50/60 p-5"
    >
      <p class="text-sm font-semibold text-emerald-950">Loading the assigned Qur'an passage…</p>
    </section>
    <section
      :if={match?({:ok, _}, @passage)}
      class="rounded-2xl border border-emerald-900/10 bg-emerald-50/60 p-5 sm:p-6"
    >
      <div class="flex items-center justify-between gap-4">
        <div>
          <p class="text-sm font-bold uppercase tracking-[0.16em] text-amber-700">Assigned āyāt</p>
          <p class="mt-1 text-sm text-stone-600">
            Ayat {@first_ayah}–{@last_ayah} of {@total_ayahs}. Read from the same portion before recording or reviewing.
          </p>
        </div>
        <div class="flex shrink-0 items-center gap-3">
          <button
            :if={@allow_show_all && @total_pages > 1}
            type="button"
            phx-click={@on_show_all}
            class="rounded-lg border border-emerald-800 px-3 py-2 text-xs font-semibold text-emerald-900 transition hover:bg-emerald-100"
          >
            {if @show_all, do: "Use pages", else: "Show all"}
          </button>
          <.icon name="hero-book-open" class="size-5 text-emerald-800" />
        </div>
      </div>
      <div class="mt-5 overflow-hidden rounded-xl border border-emerald-900/10 bg-white shadow-sm">
        <article
          :for={verse <- @visible_verses}
          class="px-4 py-5 first:border-t-0 not-first:border-t not-first:border-emerald-900/10 sm:px-6"
        >
          <div dir="rtl" lang="ar" class="flex items-start justify-end gap-3">
            <span
              aria-label={"Ayah #{verse.number}"}
              class="mt-2 rounded-full bg-amber-100 px-2 py-1 text-xs font-bold leading-none text-amber-900"
            >
              {verse.number}
            </span>
            <p class="max-w-full text-right font-serif text-2xl leading-[2.35] text-emerald-950 sm:text-[1.9rem]">
              {verse.arabic}
            </p>
          </div>
          <p
            :if={verse.translation}
            lang="en"
            class="mt-3 border-l-2 border-amber-300 pl-3 text-sm leading-7 text-stone-600 sm:pl-4"
          >
            {verse.translation}
          </p>
        </article>
      </div>
      <.pagination
        page={@page}
        total_pages={@total_pages}
        total_entries={@total_ayahs}
        item_label="āyāt"
        on_change={@on_page_change}
      />
      <p class="mt-4 text-xs text-stone-500">{elem(@passage, 1).source}</p>
    </section>
    """
  end

  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :total_entries, :integer, required: true
  attr :on_change, :string, required: true
  attr :item_label, :string, default: "records"

  def pagination(assigns) do
    assigns = assign(assigns, pages: page_items(assigns.page, assigns.total_pages))

    ~H"""
    <nav
      :if={@total_pages > 1}
      aria-label="Pagination"
      class="mt-6 flex flex-wrap items-center justify-between gap-3 border-t border-emerald-900/10 pt-4"
    >
      <p class="text-sm text-stone-600 dark:text-stone-300">
        Page {@page} of {@total_pages} · {@total_entries} {@item_label}
      </p>
      <div class="flex items-center gap-1" role="list">
        <button
          type="button"
          phx-click={@on_change}
          phx-value-page={@page - 1}
          disabled={@page == 1}
          class="rounded-lg border border-emerald-900/15 px-3 py-2 text-sm font-semibold text-emerald-900 transition hover:bg-emerald-50 disabled:cursor-not-allowed disabled:opacity-40 dark:text-emerald-100"
        >
          Previous
        </button>
        <span :for={item <- @pages}>
          <span :if={item == :gap} class="px-2 text-stone-400">…</span>
          <button
            :if={is_integer(item)}
            type="button"
            phx-click={@on_change}
            phx-value-page={item}
            aria-current={if(item == @page, do: "page")}
            class={[
              "min-w-9 rounded-lg px-3 py-2 text-sm font-semibold transition",
              if(item == @page,
                do: "bg-emerald-800 text-white",
                else: "text-emerald-900 hover:bg-emerald-50 dark:text-emerald-100"
              )
            ]}
          >
            {item}
          </button>
        </span>
        <button
          type="button"
          phx-click={@on_change}
          phx-value-page={@page + 1}
          disabled={@page == @total_pages}
          class="rounded-lg border border-emerald-900/15 px-3 py-2 text-sm font-semibold text-emerald-900 transition hover:bg-emerald-50 disabled:cursor-not-allowed disabled:opacity-40 dark:text-emerald-100"
        >
          Next
        </button>
      </div>
    </nav>
    """
  end

  defp page_items(_page, total_pages) when total_pages <= 7, do: Enum.to_list(1..total_pages)

  defp page_items(page, total_pages) when page <= 4,
    do: [1, 2, 3, 4, 5, :gap, total_pages]

  defp page_items(page, total_pages) when page >= total_pages - 3,
    do: [1, :gap, total_pages - 4, total_pages - 3, total_pages - 2, total_pages - 1, total_pages]

  defp page_items(page, total_pages), do: [1, :gap, page - 1, page, page + 1, :gap, total_pages]

  defp assign_passage_page(%{passage: {:ok, passage}} = assigns) do
    total_ayahs = length(passage.verses)

    per_page =
      if assigns.show_all, do: max(total_ayahs, 1), else: assigns.per_page

    total_pages = max(1, div(total_ayahs + per_page - 1, per_page))
    page = assigns.page |> max(1) |> min(total_pages)
    visible_verses = Enum.slice(passage.verses, per_page * (page - 1), per_page)

    assigns
    |> assign(
      visible_verses: visible_verses,
      page: page,
      total_pages: total_pages,
      total_ayahs: total_ayahs,
      first_ayah: visible_verses |> List.first() |> Map.get(:number),
      last_ayah: visible_verses |> List.last() |> Map.get(:number)
    )
  end

  defp assign_passage_page(assigns) do
    assign(assigns,
      visible_verses: [],
      total_pages: 1,
      total_ayahs: 0,
      first_ayah: nil,
      last_ayah: nil
    )
  end

  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true

  def metric(assigns) do
    ~H"""
    <div class="rounded-2xl border border-emerald-900/10 bg-white p-5 shadow-sm dark:bg-base-200">
      <div class="flex items-center justify-between">
        <span class="text-sm font-medium text-stone-600 dark:text-stone-300">{@title}</span>
        <.icon name={@icon} class="size-5 text-amber-600" />
      </div>
      <p class="mt-3 text-3xl font-bold text-emerald-950 dark:text-emerald-100">{@value}</p>
    </div>
    """
  end
end
