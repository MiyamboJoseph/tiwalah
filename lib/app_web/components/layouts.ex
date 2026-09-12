defmodule AppWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use AppWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    assigns = assign_new(assigns, :unread_notification_count, fn -> 0 end)

    ~H"""
    <header class="border-b border-emerald-950/10 bg-[#fcfaf3] px-3 py-3 dark:bg-base-100 sm:px-8 sm:py-4">
      <div class="mx-auto flex max-w-7xl items-center justify-between gap-2 sm:gap-4">
        <a
          href={if(@current_scope, do: ~p"/dashboard", else: ~p"/")}
          class="min-w-0 flex items-center gap-2 text-emerald-950 dark:text-emerald-100 sm:gap-3"
        >
          <span class="grid size-10 place-items-center rounded-xl bg-emerald-800 text-lg text-amber-200">
            ۞
          </span>
          <span class="min-w-0">
            <span class="block font-serif text-lg font-bold">Tilawah</span><span class="block text-[10px] font-bold uppercase tracking-[0.18em] text-amber-700">Recitation circle</span>
          </span>
        </a>
        <nav class="flex shrink-0 items-center gap-1 sm:gap-2">
          <.theme_toggle />
          <%= if @current_scope && @current_scope.user do %>
            <.link
              navigate={~p"/notifications"}
              class="inline-flex items-center gap-1 text-xs font-semibold text-emerald-800 sm:text-sm"
            >
              <span class="sm:hidden">Alerts</span><span class="hidden sm:inline">Notifications</span>
              <span
                :if={@unread_notification_count > 0}
                aria-label={"#{@unread_notification_count} unread notifications"}
                class="grid size-5 place-items-center rounded-full bg-amber-400 text-[11px] font-bold text-emerald-950"
              >
                {if @unread_notification_count > 9, do: "9+", else: @unread_notification_count}
              </span>
            </.link>
            <.link
              navigate={~p"/dashboard"}
              class="text-xs font-semibold text-emerald-800 sm:text-sm"
            >
              <span class="sm:hidden">Portal</span><span class="hidden sm:inline">My portal</span>
            </.link>
            <.link
              href={~p"/users/log-out"}
              method="delete"
              class="rounded-lg bg-emerald-800 px-2.5 py-2 text-xs font-semibold text-white sm:px-3 sm:text-sm"
            >
              Sign out
            </.link>
          <% else %>
            <.link
              navigate={~p"/users/log-in"}
              class="text-xs font-semibold text-emerald-800 sm:text-sm"
            >
              Sign in
            </.link>
            <.link
              navigate={~p"/users/register"}
              class="rounded-lg bg-emerald-800 px-2.5 py-2 text-xs font-semibold text-white sm:px-3 sm:text-sm"
            >
              Begin learning
            </.link>
          <% end %>
        </nav>
      </div>
    </header>

    <main class="min-h-[calc(100vh-65px)] bg-[#f8f6ee] px-4 py-6 dark:bg-base-100 sm:min-h-[calc(100vh-73px)] sm:px-6 sm:py-10 lg:px-8">
      <div class="mx-auto max-w-7xl space-y-6">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
