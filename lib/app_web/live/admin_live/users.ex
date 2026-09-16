defmodule AppWeb.AdminLive.Users do
  use AppWeb, :live_view

  alias App.Accounts

  @default_filters %{"search" => "", "role" => "all", "account_status" => "all"}

  def mount(_params, _session, socket) do
    {:ok, load_users(socket, @default_filters, 1)}
  end

  def handle_event("filter", params, socket) do
    {:noreply,
     load_users(
       socket,
       Map.merge(@default_filters, Map.take(params, Map.keys(@default_filters))),
       1
     )}
  end

  def handle_event("paginate_users", %{"page" => page}, socket),
    do: {:noreply, load_users(socket, socket.assigns.filters, page)}

  def handle_event("set_status", %{"id" => id, "status" => status}, socket) do
    case account_status(status) do
      :invalid ->
        {:noreply, put_flash(socket, :error, "That account action is invalid.")}

      status ->
        case Accounts.set_account_status(socket.assigns.current_scope, id, status) do
          {:ok, _user} ->
            message = if status == :suspended, do: "Account suspended.", else: "Account restored."

            {:noreply,
             socket
             |> put_flash(:info, message)
             |> load_users(socket.assigns.filters, socket.assigns.page)}

          {:error, :protected_account} ->
            {:noreply,
             put_flash(socket, :error, "Administrator accounts cannot be changed here.")}

          _ ->
            {:noreply, put_flash(socket, :error, "The account status could not be updated.")}
        end
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.navigation active={:users} />
      <section class="rounded-3xl bg-emerald-950 px-6 py-10 text-amber-50 shadow-lg sm:px-10">
        <p class="text-sm font-semibold uppercase tracking-[0.2em] text-amber-300">
          Administrator portal
        </p>
        <h1 class="mt-3 font-serif text-3xl font-bold sm:text-4xl">User management</h1>
        <p class="mt-3 max-w-2xl text-emerald-100">
          Find a learner or teacher, review their account status, and use suspension only when necessary.
        </p>
      </section>

      <section class="mt-6 rounded-2xl bg-white p-5 shadow-sm dark:bg-base-200 sm:p-6">
        <form phx-change="filter" class="grid gap-3 md:grid-cols-[minmax(0,1fr)_11rem_11rem]">
          <input
            name="search"
            value={@filters["search"]}
            placeholder="Search name or email"
            class="rounded-lg border border-stone-300 px-3 py-2 text-sm"
          />
          <select name="role" class="rounded-lg border border-stone-300 px-3 py-2 text-sm">
            <option value="all" selected={@filters["role"] == "all"}>All roles</option>
            <option value="student" selected={@filters["role"] == "student"}>Students</option>
            <option value="tutor" selected={@filters["role"] == "tutor"}>Tutors</option>
            <option value="admin" selected={@filters["role"] == "admin"}>Administrators</option>
          </select>
          <select name="account_status" class="rounded-lg border border-stone-300 px-3 py-2 text-sm">
            <option value="all" selected={@filters["account_status"] == "all"}>All statuses</option>
            <option value="active" selected={@filters["account_status"] == "active"}>Active</option>
            <option value="suspended" selected={@filters["account_status"] == "suspended"}>
              Suspended
            </option>
          </select>
        </form>

        <p class="mt-5 text-sm text-stone-600">{length(@users)} account(s) found.</p>
        <div class="mt-4 overflow-x-auto">
          <table class="min-w-full text-left text-sm">
            <thead class="border-b border-emerald-900/10 text-xs uppercase tracking-wide text-stone-500">
              <tr>
                <th class="px-3 py-3">User</th>
                <th class="px-3 py-3">Role</th>
                <th class="px-3 py-3">Profile</th>
                <th class="px-3 py-3">Status</th>
                <th class="px-3 py-3">Action</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-emerald-900/10">
              <tr :for={user <- @users}>
                <td class="px-3 py-4">
                  <p class="font-semibold text-emerald-950">{display_name(user)}</p>
                  <p class="mt-1 text-xs text-stone-600">{user.email}</p>
                </td>
                <td class="px-3 py-4 capitalize">{user.role}</td>
                <td class="px-3 py-4 text-xs text-stone-600">{profile_status(user)}</td>
                <td class="px-3 py-4">
                  <span class={status_class(user.account_status)}>
                    {status_label(user.account_status)}
                  </span>
                </td>
                <td class="px-3 py-4">
                  <button
                    :if={user.role != :admin and user.account_status == :active}
                    type="button"
                    phx-click="set_status"
                    phx-value-id={user.id}
                    phx-value-status="suspended"
                    data-confirm="Suspend this account? Existing sessions will lose access."
                    class="font-semibold text-rose-700 hover:underline"
                  >
                    Suspend
                  </button>
                  <button
                    :if={user.role != :admin and user.account_status == :suspended}
                    type="button"
                    phx-click="set_status"
                    phx-value-id={user.id}
                    phx-value-status="active"
                    class="font-semibold text-emerald-800 hover:underline"
                  >
                    Restore
                  </button>
                  <span :if={user.role == :admin} class="text-xs text-stone-500">Protected</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <p
          :if={@users == []}
          class="mt-5 rounded-xl border border-dashed border-emerald-900/20 p-5 text-sm text-stone-600"
        >
          No users match these filters.
        </p>
        <.pagination
          page={@page}
          total_pages={@total_pages}
          total_entries={@total_entries}
          item_label="accounts"
          on_change="paginate_users"
        />
      </section>
    </Layouts.app>
    """
  end

  defp load_users(socket, filters, page) do
    pagination = Accounts.admin_paginate_users(socket.assigns.current_scope, filters, page)

    assign(socket,
      filters: filters,
      users: pagination.entries,
      page: pagination.page,
      total_pages: pagination.total_pages,
      total_entries: pagination.total_entries
    )
  end

  defp account_status("active"), do: :active
  defp account_status("suspended"), do: :suspended
  defp account_status(_), do: :invalid

  defp display_name(user),
    do: [user.first_name, user.last_name] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ")

  defp profile_status(%{role: :tutor, tutor_verification_status: status}), do: "Tutor: #{status}"
  defp profile_status(_user), do: "Standard profile"
  defp status_label(:active), do: "Active"
  defp status_label(:suspended), do: "Suspended"

  defp status_class(:active),
    do: "rounded-full bg-emerald-100 px-2 py-1 text-xs font-semibold text-emerald-800"

  defp status_class(:suspended),
    do: "rounded-full bg-rose-100 px-2 py-1 text-xs font-semibold text-rose-800"
end
