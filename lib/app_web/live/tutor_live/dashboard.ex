defmodule AppWeb.TutorLive.Dashboard do
  use AppWeb, :live_view

  alias App.Recitations
  alias App.Recitations.Assignment
  alias App.Quran

  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    if scope.user.role == :tutor do
      if connected?(socket), do: Recitations.subscribe_tutor(scope.user.id)
      {:ok, load_dashboard(socket)}
    else
      {:ok,
       socket
       |> put_flash(:error, "This portal is for tutors.")
       |> push_navigate(to: ~p"/dashboard")}
    end
  end

  def handle_info({:recitation_changed, _event, _assignment_id}, socket) do
    {:noreply, load_dashboard(socket)}
  end

  def handle_event("paginate_assignments", %{"page" => page}, socket) do
    {:noreply, load_dashboard(socket, page)}
  end

  def handle_event("validate", %{"assignment" => params}, socket) do
    changeset = Assignment.changeset(%Assignment{}, params) |> Map.put(:action, :validate)
    {:noreply, assign(socket, form: to_form(changeset, as: "assignment"))}
  end

  def handle_event("assign", %{"assignment" => %{"student_id" => student_id} = params}, socket) do
    case Recitations.create_assignment(
           socket.assigns.current_scope,
           student_id,
           Map.delete(params, "student_id")
         ) do
      {:ok, _assignment} ->
        {:noreply,
         socket |> put_flash(:info, "Portion assigned successfully.") |> load_dashboard(1)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "assignment"))}
    end
  end

  def handle_event("request_student", %{"connection" => %{"email" => email}}, socket) do
    case Recitations.request_student_connection(socket.assigns.current_scope, email) do
      {:ok, _connection} ->
        {:noreply,
         socket
         |> assign(connection_form: to_form(%{"email" => ""}, as: "connection"))
         |> put_flash(
           :info,
           "Tutor request sent. The student must accept before you can assign a portion."
         )}

      {:error, :student_not_found} ->
        {:noreply,
         put_flash(
           socket,
           :info,
           "If that student has a Tilawah account, they will receive your connection request."
         )}

      _ ->
        {:noreply, put_flash(socket, :error, "The tutor request could not be created.")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="rounded-3xl bg-emerald-950 px-6 py-10 text-amber-50 shadow-lg sm:px-10">
        <p class="text-sm font-semibold tracking-[0.2em] text-amber-300 uppercase">Tutor portal</p>
        <h1 class="mt-3 font-serif text-3xl font-bold sm:text-4xl">
          Guide each recitation with ihsān.
        </h1>
        <p class="mt-3 max-w-2xl text-emerald-100">
          Assign a focused portion, listen attentively, and give gentle, useful correction.
        </p>
      </section>
      <section class="grid gap-4 sm:grid-cols-3">
        <.metric title="Active assignments" value={@assignment_counts.total} icon="hero-book-open" /><.metric
          title="Awaiting review"
          value={@assignment_counts.submitted}
          icon="hero-headphones"
        /><.metric title="Students" value={length(@students)} icon="hero-user-group" />
      </section>
      <section class="grid gap-6 lg:grid-cols-[1.1fr_.9fr]">
        <div>
          <div class="mb-5">
            <p class="text-sm font-bold uppercase tracking-[0.18em] text-amber-700">Review queue</p>
            <h2 class="mt-1 font-serif text-2xl font-bold text-emerald-950 dark:text-emerald-100">
              Your assigned portions
            </h2>
          </div>
          <div
            :if={@assignments == []}
            class="rounded-2xl border border-dashed border-emerald-900/20 bg-white p-8 text-stone-600 dark:bg-base-200"
          >
            Create an assignment to begin your recitation circle.
          </div>
          <div class="space-y-4">
            <.assignment_card :for={assignment <- @assignments} assignment={assignment}>
              <:action>
                <.link
                  navigate={~p"/tutor/reviews/#{assignment.id}"}
                  class="font-semibold text-emerald-800 hover:underline"
                >
                  Review submissions →
                </.link>
              </:action>
            </.assignment_card>
          </div>
          <.pagination
            page={@page}
            total_pages={@total_pages}
            total_entries={@assignment_counts.total}
            on_change="paginate_assignments"
          />
        </div>
        <aside class="rounded-2xl bg-white p-6 shadow-sm dark:bg-base-200">
          <.form
            for={@connection_form}
            id="student-connection-form"
            phx-submit="request_student"
            class="mb-6 border-b border-emerald-900/10 pb-6"
          >
            <h2 class="font-serif text-xl font-bold text-emerald-950 dark:text-emerald-100">
              Invite a student
            </h2>
            <p class="mt-1 text-sm text-stone-600 dark:text-stone-300">
              Send a private connection request using the student’s registered email.
            </p>
            <div class="mt-4 flex flex-col gap-3 sm:flex-row lg:flex-col">
              <.input
                field={@connection_form[:email]}
                type="email"
                label="Student email"
                placeholder="student@example.com"
                required
              />
              <.button class="bg-emerald-800 text-white hover:bg-emerald-900">
                Request connection
              </.button>
            </div>
          </.form>
          <h2 class="font-serif text-xl font-bold text-emerald-950 dark:text-emerald-100">
            Assign a portion
          </h2>
          <p class="mt-1 text-sm text-stone-600 dark:text-stone-300">
            Give one student a clear, manageable section.
          </p>
          <.form
            for={@form}
            id="assignment-form"
            phx-change="validate"
            phx-submit="assign"
            class="mt-5 space-y-3"
          >
            <.input
              field={@form[:student_id]}
              type="select"
              label="Student"
              prompt="Select a student"
              options={Enum.map(@students, &{student_label(&1), &1.id})}
            /><.input
              field={@form[:title]}
              type="text"
              label="Practice title"
              placeholder="Morning revision"
            />
            <div class="grid grid-cols-2 gap-3">
              <.input field={@form[:juz_number]} type="number" label="Juz" min="1" max="30" /><.input
                field={@form[:surah_name]}
                type="select"
                label="Surah"
                prompt="Select a surah"
                options={Quran.surah_options()}
              />
            </div>
            <div class="grid grid-cols-2 gap-3">
              <.input field={@form[:ayah_from]} type="number" label="First ayah" min="1" /><.input
                field={@form[:ayah_to]}
                type="number"
                label="Last ayah"
                min="1"
              />
            </div>
            <.input field={@form[:due_date]} type="date" label="Due date (optional)" />
            <.button class="w-full bg-emerald-800 text-white hover:bg-emerald-900">
              Assign portion
            </.button>
          </.form>
        </aside>
      </section>
    </Layouts.app>
    """
  end

  defp load_dashboard(socket, page \\ nil) do
    scope = socket.assigns.current_scope
    changeset = Assignment.changeset(%Assignment{}, %{})
    page = page || Map.get(socket.assigns, :page, 1)
    assignment_page = Recitations.paginate_assignments(scope, page)

    assign(socket,
      assignments: assignment_page.entries,
      assignment_counts: Recitations.assignment_counts(scope),
      page: assignment_page.page,
      total_pages: assignment_page.total_pages,
      students: Recitations.list_students(scope),
      form: to_form(changeset, as: "assignment"),
      connection_form: to_form(%{"email" => ""}, as: "connection")
    )
  end

  defp student_label(student) do
    name = [student.first_name, student.last_name] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
    if name == "", do: student.email, else: "#{name} (#{student.email})"
  end
end
