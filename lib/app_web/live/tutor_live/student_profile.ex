defmodule AppWeb.TutorLive.StudentProfile do
  use AppWeb, :live_view
  alias App.Recitations

  def mount(%{"student_id" => student_id}, _session, socket) do
    case {socket.assigns.current_scope.user.role,
          Recitations.student_overview(socket.assigns.current_scope, student_id)} do
      {:tutor, {:ok, overview}} ->
        {:ok, assign(socket, overview: overview)}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "That student profile is unavailable.")
         |> push_navigate(to: ~p"/tutor")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-5xl">
        <.link navigate={~p"/tutor"} class="text-sm font-semibold text-emerald-800">
          ← Back to tutor portal
        </.link>
        <section class="mt-5 rounded-3xl bg-emerald-950 p-8 text-amber-50 shadow-lg">
          <p class="text-sm font-bold uppercase tracking-[0.18em] text-amber-300">Student profile</p>
          <h1 class="mt-2 font-serif text-3xl font-bold">
            {@overview.student.first_name} {@overview.student.last_name}
          </h1>
          <p class="mt-2 text-emerald-100">
            {@overview.student.email} · {@overview.student.location || "Location not stated"}
          </p>
        </section>
        <section class="mt-6 grid gap-4 sm:grid-cols-3">
          <.metric title="Assignments" value={length(@overview.assignments)} icon="hero-book-open" />
          <.metric title="Recordings" value={length(@overview.submissions)} icon="hero-microphone" />
          <.metric
            title="Corrections tracked"
            value={Enum.sum(Enum.map(@overview.correction_trends, &elem(&1, 1)))}
            icon="hero-chart-bar"
          />
        </section>
        <section class="mt-6 rounded-2xl bg-white p-6 shadow-sm dark:bg-base-200">
          <p class="text-sm font-bold uppercase tracking-[0.18em] text-amber-700">
            Correction trends
          </p>
          <div :if={@overview.correction_trends == []} class="mt-3 text-sm text-stone-600">
            No reviewed recitations yet.
          </div>
          <div class="mt-4 space-y-3">
            <div
              :for={{area, count} <- @overview.correction_trends}
              class="flex items-center justify-between rounded-xl bg-amber-50 px-4 py-3"
            >
              <span class="font-medium text-emerald-950">{area}</span><span class="rounded-full bg-amber-200 px-3 py-1 text-sm font-bold text-amber-900">{count}</span>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
