defmodule AppWeb.AdminLive.Connections do
  use AppWeb, :live_view

  alias App.Admin

  def mount(_params, _session, socket), do: {:ok, load_connections(socket, "all", 1)}

  def handle_event("filter", %{"status" => status}, socket),
    do: {:noreply, load_connections(socket, status, 1)}

  def handle_event("paginate_connections", %{"page" => page}, socket),
    do: {:noreply, load_connections(socket, socket.assigns.status, page)}

  def handle_event("end_connection", %{"_id" => id, "reason" => reason}, socket) do
    case Admin.end_connection(socket.assigns.current_scope, id, reason) do
      {:ok, _connection} ->
        {:noreply,
         socket
         |> put_flash(:info, "Connection closed and both users were notified.")
         |> load_connections(socket.assigns.status, socket.assigns.page)}

      {:error, :reason_required} ->
        {:noreply,
         put_flash(socket, :error, "Please provide a clear reason before closing a connection.")}

      _ ->
        {:noreply, put_flash(socket, :error, "The connection could not be closed.")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.navigation active={:connections} />
      <section class="rounded-3xl bg-emerald-950 px-6 py-10 text-amber-50 shadow-lg sm:px-10">
        <p class="text-sm font-semibold uppercase tracking-[0.2em] text-amber-300">
          Administrator portal
        </p>
        <h1 class="mt-3 font-serif text-3xl font-bold sm:text-4xl">Learning connections</h1>
        <p class="mt-3 max-w-2xl text-emerald-100">
          Monitor student–tutor relationships and intervene only when a connection needs to be safely closed.
        </p>
      </section>

      <section class="mt-6 rounded-2xl bg-white p-5 shadow-sm dark:bg-base-200 sm:p-6">
        <form phx-change="filter" class="flex flex-wrap items-center justify-between gap-3">
          <p class="text-sm text-stone-600">{@connection_count} connection(s) shown.</p>
          <select name="status" class="rounded-lg border border-stone-300 px-3 py-2 text-sm">
            <option value="all" selected={@status == "all"}>All connections</option>
            <option value="active" selected={@status == "active"}>Active</option>
            <option value="pending" selected={@status == "pending"}>Pending</option>
          </select>
        </form>

        <p
          :if={@connections == []}
          class="mt-5 rounded-xl border border-dashed border-emerald-900/20 p-5 text-sm text-stone-600"
        >
          No connections match this filter.
        </p>
        <div :if={@connections != []} class="mt-5 grid gap-4 lg:grid-cols-2">
          <article
            :for={connection <- @connections}
            class="rounded-2xl border border-emerald-900/10 p-5"
          >
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div>
                <p class="text-xs font-bold uppercase tracking-wide text-amber-700">
                  {connection.status} · requested by {connection.requested_by}
                </p>
                <h2 class="mt-2 font-serif text-xl font-bold text-emerald-950">
                  {display_name(connection.student)}
                </h2>
                <p class="text-sm text-stone-600">Student · {connection.student.email}</p>
              </div>
              <time class="text-xs text-stone-500">
                {Calendar.strftime(connection.inserted_at, "%d %b %Y")}
              </time>
            </div>
            <div class="mt-4 rounded-xl bg-emerald-50 p-4 text-sm">
              <p class="font-semibold text-emerald-950">Tutor: {display_name(connection.tutor)}</p>
              <p class="mt-1 text-stone-600">{connection.tutor.email}</p>
            </div>
            <form class="mt-4" phx-submit="end_connection">
              <input type="hidden" name="_id" value={connection.id} />
              <label
                class="text-sm font-semibold text-emerald-950"
                for={"close-reason-#{connection.id}"}
              >
                Reason to close
              </label>
              <textarea
                id={"close-reason-#{connection.id}"}
                name="reason"
                required
                rows="2"
                placeholder="Explain the intervention to both participants."
                class="mt-2 w-full rounded-lg border border-stone-300 px-3 py-2 text-sm"
              ></textarea>
              <button
                type="submit"
                data-confirm="Close this learning connection and notify both users?"
                class="mt-2 rounded-lg border border-rose-300 px-4 py-2 text-sm font-semibold text-rose-800 hover:bg-rose-50"
              >
                Close connection
              </button>
            </form>
          </article>
        </div>
        <.pagination
          page={@page}
          total_pages={@total_pages}
          total_entries={@total_entries}
          item_label="connections"
          on_change="paginate_connections"
        />
      </section>
    </Layouts.app>
    """
  end

  defp load_connections(socket, status, page) do
    pagination = Admin.paginate_connections(socket.assigns.current_scope, status, page)

    assign(socket,
      status: status,
      connections: pagination.entries,
      connection_count: pagination.total_entries,
      page: pagination.page,
      total_pages: pagination.total_pages,
      total_entries: pagination.total_entries
    )
  end

  defp display_name(user),
    do: [user.first_name, user.last_name] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ")
end
