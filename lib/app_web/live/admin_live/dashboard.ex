defmodule AppWeb.AdminLive.Dashboard do
  use AppWeb, :live_view

  alias App.Admin

  def mount(_params, _session, socket) do
    {:ok, assign(socket, dashboard: Admin.dashboard(socket.assigns.current_scope))}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.navigation active={:overview} />

      <section class="rounded-3xl bg-emerald-950 px-6 py-10 text-amber-50 shadow-lg sm:px-10">
        <p class="text-sm font-semibold uppercase tracking-[0.2em] text-amber-300">
          Administrator portal
        </p>
        <h1 class="mt-3 font-serif text-3xl font-bold sm:text-4xl">Tilawah operations</h1>
        <p class="mt-3 max-w-2xl text-emerald-100">
          Review tutor applications, safeguard accounts, and keep learning connections healthy.
        </p>
      </section>

      <section class="mt-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <.admin_metric
          label="Tutor reviews"
          value={@dashboard.pending_tutors}
          detail="Awaiting a decision"
        />
        <.admin_metric
          label="Verified tutors"
          value={@dashboard.verified_tutors}
          detail="Available to students"
        />
        <.admin_metric label="Students" value={@dashboard.students} detail="Registered learners" />
        <.admin_metric
          label="Awaiting review"
          value={@dashboard.awaiting_review}
          detail="Submitted recordings"
        />
      </section>

      <section class="mt-6 grid gap-6 lg:grid-cols-2">
        <article class="rounded-2xl bg-white p-6 shadow-sm dark:bg-base-200">
          <p class="text-sm font-bold uppercase tracking-[0.18em] text-amber-700">Learning network</p>
          <h2 class="mt-1 font-serif text-2xl font-bold text-emerald-950 dark:text-emerald-100">
            Connections
          </h2>
          <dl class="mt-5 grid grid-cols-2 gap-4">
            <div class="rounded-xl bg-emerald-50 p-4">
              <dt class="text-sm text-stone-600">Active</dt>
              <dd class="mt-1 text-2xl font-bold text-emerald-950">
                {@dashboard.active_connections}
              </dd>
            </div>
            <div class="rounded-xl bg-amber-50 p-4">
              <dt class="text-sm text-stone-600">Pending</dt>
              <dd class="mt-1 text-2xl font-bold text-emerald-950">
                {@dashboard.pending_connections}
              </dd>
            </div>
          </dl>
          <.link
            navigate={~p"/admin/connections"}
            class="mt-5 inline-block text-sm font-semibold text-emerald-800 hover:underline"
          >
            Review connections →
          </.link>
        </article>

        <article class="rounded-2xl bg-white p-6 shadow-sm dark:bg-base-200">
          <p class="text-sm font-bold uppercase tracking-[0.18em] text-amber-700">Account safety</p>
          <h2 class="mt-1 font-serif text-2xl font-bold text-emerald-950 dark:text-emerald-100">
            Account status
          </h2>
          <p class="mt-4 text-sm leading-6 text-stone-600">
            {@dashboard.suspended_accounts} account(s) are suspended. Suspension prevents sign-in while retaining the record and its audit trail.
          </p>
          <.link
            navigate={~p"/admin/users"}
            class="mt-5 inline-block text-sm font-semibold text-emerald-800 hover:underline"
          >
            Manage users →
          </.link>
        </article>
      </section>

      <section class="mt-6 rounded-2xl bg-white p-6 shadow-sm dark:bg-base-200">
        <div class="flex flex-wrap items-end justify-between gap-3">
          <div>
            <p class="text-sm font-bold uppercase tracking-[0.18em] text-amber-700">
              Teaching capacity
            </p>
            <h2 class="mt-1 font-serif text-2xl font-bold text-emerald-950 dark:text-emerald-100">
              Tutor roster
            </h2>
          </div>
          <.link
            navigate={~p"/admin/users"}
            class="text-sm font-semibold text-emerald-800 hover:underline"
          >
            Manage tutors →
          </.link>
        </div>
        <p
          :if={@dashboard.tutor_roster == []}
          class="mt-5 rounded-xl border border-dashed border-emerald-900/20 p-5 text-sm text-stone-600"
        >
          No tutor accounts have been registered yet.
        </p>
        <div :if={@dashboard.tutor_roster != []} class="mt-5 overflow-x-auto">
          <table class="min-w-full text-left text-sm">
            <thead class="border-b border-emerald-900/10 text-xs uppercase tracking-wide text-stone-500">
              <tr>
                <th class="px-3 py-3">Tutor</th>
                <th class="px-3 py-3">Verification</th>
                <th class="px-3 py-3">Account</th>
                <th class="px-3 py-3">Connected students</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-emerald-900/10">
              <tr :for={entry <- @dashboard.tutor_roster}>
                <td class="px-3 py-4">
                  <p class="font-semibold text-emerald-950">{actor_name(entry.tutor)}</p>
                  <p class="mt-1 text-xs text-stone-600">{entry.tutor.email}</p>
                </td>
                <td class="px-3 py-4 capitalize">{entry.tutor.tutor_verification_status}</td>
                <td class="px-3 py-4 capitalize">{entry.tutor.account_status}</td>
                <td class="px-3 py-4 font-semibold text-emerald-950">
                  {entry.connected_students} / {entry.tutor.tutor_student_limit}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section class="mt-6 rounded-2xl bg-white p-6 shadow-sm dark:bg-base-200">
        <div class="flex flex-wrap items-end justify-between gap-3">
          <div>
            <p class="text-sm font-bold uppercase tracking-[0.18em] text-amber-700">Accountability</p>
            <h2 class="mt-1 font-serif text-2xl font-bold text-emerald-950 dark:text-emerald-100">
              Recent administrator activity
            </h2>
          </div>
          <.link
            navigate={~p"/admin/tutors"}
            class="text-sm font-semibold text-emerald-800 hover:underline"
          >
            Review tutors →
          </.link>
        </div>
        <p
          :if={@dashboard.recent_events == []}
          class="mt-5 rounded-xl border border-dashed border-emerald-900/20 p-5 text-sm text-stone-600"
        >
          Administrator decisions will appear here once an action is taken.
        </p>
        <ol :if={@dashboard.recent_events != []} class="mt-5 divide-y divide-emerald-900/10">
          <li
            :for={event <- @dashboard.recent_events}
            class="flex flex-wrap justify-between gap-3 py-4 text-sm"
          >
            <span class="font-semibold text-emerald-950">{event_label(event.action)}</span>
            <span class="text-stone-600">
              {actor_name(event.actor)} → {actor_name(event.target_user)}
            </span>
            <time class="text-stone-500">
              {Calendar.strftime(event.inserted_at, "%d %b %Y, %H:%M")}
            </time>
          </li>
        </ol>
      </section>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :detail, :string, required: true

  defp admin_metric(assigns) do
    ~H"""
    <article class="rounded-2xl bg-white p-5 shadow-sm dark:bg-base-200">
      <p class="text-sm text-stone-600">{@label}</p>
      <p class="mt-3 text-3xl font-bold text-emerald-950 dark:text-emerald-100">{@value}</p>
      <p class="mt-1 text-xs text-stone-500">{@detail}</p>
    </article>
    """
  end

  defp event_label("tutor_verified"), do: "Tutor verified"
  defp event_label("tutor_rejected"), do: "Tutor declined"
  defp event_label("account_suspended"), do: "Account suspended"
  defp event_label("account_active"), do: "Account restored"
  defp event_label("connection_ended"), do: "Connection closed"
  defp event_label(_), do: "Administrator action"

  defp actor_name(nil), do: "System"

  defp actor_name(user),
    do: [user.first_name, user.last_name] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
end
