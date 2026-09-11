defmodule AppWeb.DashboardLive do
  use AppWeb, :live_view

  alias App.Recitations

  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    case scope.user.role do
      :student ->
        if connected?(socket), do: Recitations.subscribe_student(scope.user.id)
        {:ok, load_dashboard(socket)}

      :tutor ->
        {:ok, push_navigate(socket, to: ~p"/tutor")}
    end
  end

  def handle_info({:recitation_changed, _event, _assignment_id}, socket) do
    {:noreply, load_dashboard(socket)}
  end

  def handle_event("paginate_assignments", %{"page" => page}, socket) do
    {:noreply, load_dashboard(socket, page)}
  end

  def render(assigns) do
    pending = assigns.assignment_counts.assigned + assigns.assignment_counts.repeat_required
    reviewed = assigns.assignment_counts.reviewed
    assigns = assign(assigns, pending: pending, reviewed: reviewed)

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="rounded-3xl bg-emerald-950 px-6 py-10 text-amber-50 shadow-lg sm:px-10">
        <p class="text-sm font-semibold tracking-[0.2em] text-amber-300 uppercase">Student portal</p>
        <h1 class="mt-3 font-serif text-3xl font-bold sm:text-4xl">
          As-salāmu ʿalaykum, {student_greeting(@current_scope.user)}
        </h1>
        <p class="mt-3 max-w-2xl text-emerald-100">
          Practice with care, submit with confidence, and grow with every correction.
        </p>
      </section>
      <section class="grid gap-4 sm:grid-cols-3">
        <.metric title="Assigned portions" value={@assignment_counts.total} icon="hero-book-open" />
        <.metric title="Ready to record" value={@pending} icon="hero-microphone" />
        <.metric title="Approved" value={@reviewed} icon="hero-check-badge" />
      </section>
      <section>
        <div class="mb-5 flex items-end justify-between">
          <div>
            <p class="text-sm font-bold uppercase tracking-[0.18em] text-amber-700">Your practice</p>
            <h2 class="mt-1 font-serif text-2xl font-bold text-emerald-950 dark:text-emerald-100">
              Assigned recitations
            </h2>
          </div>
        </div>
        <div
          :if={@assignments == []}
          class="rounded-2xl border border-dashed border-emerald-900/20 bg-white p-10 text-center text-stone-600 dark:bg-base-200"
        >
          Your tutor has not assigned a portion yet. Your next recitation will appear here.
        </div>
        <div :if={@assignments != []} class="grid gap-4 lg:grid-cols-2">
          <.assignment_card :for={assignment <- @assignments} assignment={assignment}>
            <:detail>
              <.feedback_categories
                label="Correction areas"
                categories={latest_feedback_categories(assignment)}
              />
            </:detail>
            <:action>
              <%= if assignment.status in [:assigned, :repeat_required] do %>
                <.link
                  navigate={~p"/recitations/new/#{assignment.id}"}
                  class="font-semibold text-emerald-800 hover:underline"
                >
                  Record recitation →
                </.link>
              <% else %>
                <.link
                  navigate={~p"/recitations/#{assignment.id}"}
                  class="font-semibold text-emerald-800 hover:underline"
                >
                  {assignment_action_label(assignment.status)} →
                </.link>
              <% end %>
            </:action>
          </.assignment_card>
        </div>
        <.pagination
          page={@page}
          total_pages={@total_pages}
          total_entries={@assignment_counts.total}
          on_change="paginate_assignments"
        />
      </section>
    </Layouts.app>
    """
  end

  defp student_greeting(%{first_name: first_name})
       when is_binary(first_name) and first_name != "",
       do: first_name

  defp student_greeting(user), do: user.email

  defp assignment_action_label(:submitted), do: "Awaiting tutor review"
  defp assignment_action_label(:reviewed), do: "View feedback"

  defp latest_feedback_categories(%{status: status, submissions: submissions})
       when status in [:reviewed, :repeat_required] do
    submissions
    |> Enum.find(&(&1.status == status))
    |> case do
      nil -> []
      submission -> submission.feedback_categories || []
    end
  end

  defp latest_feedback_categories(_assignment), do: []

  defp load_dashboard(socket, page \\ nil) do
    page = page || Map.get(socket.assigns, :page, 1)
    assignment_page = Recitations.paginate_assignments(socket.assigns.current_scope, page)

    assign(socket,
      assignments: assignment_page.entries,
      assignment_counts: Recitations.assignment_counts(socket.assigns.current_scope),
      page: assignment_page.page,
      total_pages: assignment_page.total_pages
    )
  end
end
