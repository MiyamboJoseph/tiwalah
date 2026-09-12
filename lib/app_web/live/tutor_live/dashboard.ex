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

    {:noreply,
     assign(socket,
       form: to_form(changeset, as: "assignment"),
       template_due_in_days: Map.get(params, "template_due_in_days")
     )}
  end

  def handle_event("assign", %{"assignment" => %{"action" => "save_template"} = params}, socket) do
    attrs =
      params
      |> Map.drop(["student_id", "action", "due_date", "template_due_in_days"])
      |> Map.put("due_in_days", Map.get(params, "template_due_in_days"))

    case Recitations.create_template(socket.assigns.current_scope, attrs) do
      {:ok, _template} ->
        {:noreply, socket |> put_flash(:info, "Assignment template saved.") |> load_dashboard()}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "assignment"))}
    end
  end

  def handle_event("assign", %{"assignment" => %{"student_id" => student_id} = params}, socket) do
    attrs = Map.drop(params, ["student_id", "action", "template_due_in_days"])

    case Recitations.create_assignment(socket.assigns.current_scope, student_id, attrs) do
      {:ok, _assignment} ->
        {:noreply,
         socket |> put_flash(:info, "Portion assigned successfully.") |> load_dashboard(1)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "assignment"))}
    end
  end

  def handle_event("apply_template", %{"template_id" => id}, socket) do
    case Enum.find(socket.assigns.templates, &(to_string(&1.id) == id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "That template is unavailable.")}

      template ->
        values =
          socket.assigns.form.params
          |> Map.merge(
            Map.take(template, [:title, :juz_number, :surah_name, :ayah_from, :ayah_to])
            |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
          )

        due_date =
          if is_integer(template.due_in_days) do
            Date.utc_today() |> Date.add(template.due_in_days) |> Date.to_iso8601()
          end

        values = if due_date, do: Map.put(values, "due_date", due_date), else: values

        {:noreply,
         assign(socket,
           form: to_form(values, as: "assignment"),
           template_due_in_days: template.due_in_days
         )}
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

      {:error, :already_requested} ->
        {:noreply, put_flash(socket, :info, "That student already has your pending request.")}

      {:error, :already_connected} ->
        {:noreply, put_flash(socket, :info, "That student is already in your recitation circle.")}

      _ ->
        {:noreply, put_flash(socket, :error, "The tutor request could not be created.")}
    end
  end

  def handle_event("disconnect_student", %{"id" => id}, socket) do
    case Recitations.disconnect_tutor_student(socket.assigns.current_scope, id) do
      {:ok, _connection} ->
        {:noreply, socket |> put_flash(:info, "Student connection ended.") |> load_dashboard()}

      _ ->
        {:noreply, put_flash(socket, :error, "That student connection is no longer available.")}
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
        <p class="mt-4 inline-flex rounded-full bg-white/10 px-3 py-1 text-sm font-semibold text-amber-100">
          {verification_message(@current_scope.user.tutor_verification_status)}
        </p>
      </section>
      <section class="grid gap-4 sm:grid-cols-3">
        <.metric title="Active assignments" value={@assignment_counts.active} icon="hero-book-open" /><.metric
          title="Awaiting review"
          value={@assignment_counts.submitted}
          icon="hero-headphones"
        /><.metric title="Students" value={length(@students)} icon="hero-user-group" />
      </section>
      <section :if={@students != []} class="rounded-2xl bg-white p-5 shadow-sm dark:bg-base-200">
        <p class="text-sm font-bold uppercase tracking-[0.18em] text-amber-700">Your students</p>
        <div class="mt-3 flex flex-wrap gap-2">
          <div
            :for={connection <- @connections}
            class="flex items-center gap-2 rounded-lg border border-emerald-800 px-3 py-2"
          >
            <.link
              navigate={~p"/tutor/students/#{connection.student.id}"}
              class="text-sm font-semibold text-emerald-800 hover:underline"
            >
              {student_label(connection.student)}
            </.link>
            <button
              type="button"
              phx-click="disconnect_student"
              phx-value-id={connection.id}
              data-confirm="End this student connection? Existing recitation history will remain available."
              class="text-xs font-semibold text-rose-700 hover:underline"
            >
              End
            </button>
          </div>
        </div>
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
            <div
              :if={@templates != []}
              class="rounded-xl border border-emerald-900/10 bg-emerald-50/50 p-3"
            >
              <label class="text-sm font-semibold text-emerald-950">Start from a template</label>
              <div class="mt-2 flex flex-wrap gap-2">
                <button
                  :for={template <- @templates}
                  type="button"
                  phx-click="apply_template"
                  phx-value-template_id={template.id}
                  class="rounded-lg border border-emerald-800 px-2.5 py-1.5 text-xs font-semibold text-emerald-800 hover:bg-emerald-100"
                >
                  {template.title}
                </button>
              </div>
              <p class="mt-1 text-xs text-stone-500">
                Templates can be saved after entering a portion below.
              </p>
            </div>
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
            <label class="block text-sm font-medium text-stone-700">
              Template due in days
              <span class="text-stone-400">(used only when saving a template)</span>
              <input
                type="number"
                name="assignment[template_due_in_days]"
                value={@template_due_in_days}
                min="0"
                class="mt-1 block w-full rounded-lg border border-stone-300 bg-white px-3 py-2 text-sm"
              />
            </label>
            <.button class="w-full bg-emerald-800 text-white hover:bg-emerald-900">
              Assign portion
            </.button>
            <button
              type="submit"
              name="assignment[action]"
              value="save_template"
              class="w-full rounded-lg border border-emerald-800 px-3 py-2 text-sm font-semibold text-emerald-800 hover:bg-emerald-50"
            >
              Save as template
            </button>
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
      connections: Recitations.list_active_connections(scope),
      form: to_form(changeset, as: "assignment"),
      template_due_in_days: nil,
      connection_form: to_form(%{"email" => ""}, as: "connection"),
      templates: Recitations.list_templates(scope)
    )
  end

  defp student_label(student) do
    name = [student.first_name, student.last_name] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
    if name == "", do: student.email, else: "#{name} (#{student.email})"
  end

  defp verification_message(:verified), do: "Tutor profile verified"
  defp verification_message(:pending), do: "Credentials submitted · verification pending"
  defp verification_message(:rejected), do: "Verification needs attention"
  defp verification_message(_status), do: "Tutor profile"
end
