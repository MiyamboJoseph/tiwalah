defmodule AppWeb.AdminComponents do
  use Phoenix.Component

  use AppWeb, :verified_routes

  attr :active, :atom, required: true

  def navigation(assigns) do
    ~H"""
    <nav aria-label="Administrator sections" class="mb-6 flex flex-wrap gap-2">
      <.link navigate={~p"/admin"} class={nav_class(@active == :overview)}>Overview</.link>
      <.link navigate={~p"/admin/tutors"} class={nav_class(@active == :tutors)}>Tutor review</.link>
      <.link navigate={~p"/admin/users"} class={nav_class(@active == :users)}>Users</.link>
      <.link navigate={~p"/admin/connections"} class={nav_class(@active == :connections)}>
        Connections
      </.link>
    </nav>
    """
  end

  defp nav_class(true),
    do: "rounded-full bg-emerald-800 px-4 py-2 text-sm font-semibold text-white"

  defp nav_class(false),
    do:
      "rounded-full border border-emerald-900/15 bg-white px-4 py-2 text-sm font-semibold text-emerald-900 hover:bg-emerald-50"
end
