defmodule AppWeb.TutorLive.Review do
  use AppWeb, :live_view

  alias App.Recitations
  alias App.UmmahApi.Quran, as: UmmahQuran

  def mount(%{"assignment_id" => assignment_id}, _session, socket) do
    scope = socket.assigns.current_scope

    if scope.user.role == :tutor do
      case Recitations.get_assignment(scope, assignment_id) do
        nil ->
          {:ok,
           socket
           |> put_flash(:error, "That assignment is unavailable.")
           |> push_navigate(to: ~p"/tutor")}

        assignment ->
          if connected?(socket), do: Recitations.subscribe_tutor(scope.user.id)

          {:ok,
           socket
           |> assign(
             assignment: assignment,
             forms: review_forms(assignment),
             quran_passage: :loading,
             passage_page: 1,
             show_all_passage: false
           )
           |> load_passage(assignment)}
      end
    else
      {:ok,
       socket
       |> put_flash(:error, "This portal is for tutors.")
       |> push_navigate(to: ~p"/dashboard")}
    end
  end

  def handle_info({:recitation_changed, _event, assignment_id}, socket) do
    case Recitations.get_assignment(socket.assigns.current_scope, assignment_id) do
      nil ->
        {:noreply, push_navigate(socket, to: ~p"/tutor")}

      assignment ->
        {:noreply, assign(socket, assignment: assignment, forms: review_forms(assignment))}
    end
  end

  def handle_info({:quran_passage_loaded, result}, socket),
    do: {:noreply, assign(socket, quran_passage: result)}

  def handle_event("paginate_passage", %{"page" => page}, socket) do
    {:noreply, assign(socket, passage_page: page_number(page))}
  end

  def handle_event("toggle_passage_view", _params, socket) do
    {:noreply,
     assign(socket,
       show_all_passage: !socket.assigns.show_all_passage,
       passage_page: 1
     )}
  end

  def handle_event("review", %{"submission_id" => id, "review" => params}, socket) do
    case Recitations.review_submission(socket.assigns.current_scope, id, params) do
      {:ok, _} ->
        assignment =
          Recitations.get_assignment!(socket.assigns.current_scope, socket.assigns.assignment.id)

        {:noreply,
         socket
         |> assign(assignment: assignment, forms: review_forms(assignment))
         |> put_flash(:info, "Feedback sent to the student.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "That submission is unavailable.")}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Could not save feedback: #{inspect(changeset.errors)}")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.link navigate={~p"/tutor"} class="text-sm font-semibold text-emerald-800">
        ← Back to tutor portal
      </.link>
      <section class="mt-5 rounded-3xl bg-white p-6 shadow-sm dark:bg-base-200">
        <p class="text-sm font-bold uppercase tracking-[0.18em] text-amber-700">
          {@assignment.student.email} · Juz {@assignment.juz_number}
        </p>
        <h1 class="mt-2 font-serif text-3xl font-bold text-emerald-950 dark:text-emerald-100">
          {@assignment.title}
        </h1>
        <p class="mt-2 text-stone-600 dark:text-stone-300">
          {@assignment.surah_name}, ayah {@assignment.ayah_from}–{@assignment.ayah_to}
        </p>
      </section>
      <div class="mt-6">
        <.quran_passage
          passage={@quran_passage}
          page={@passage_page}
          on_page_change="paginate_passage"
          allow_show_all
          show_all={@show_all_passage}
          on_show_all="toggle_passage_view"
        />
      </div>
      <section class="mt-6 space-y-5">
        <div
          :if={@assignment.submissions == []}
          class="rounded-2xl border border-dashed border-emerald-900/20 bg-white p-8 text-stone-600 dark:bg-base-200"
        >
          No recording has been submitted yet.
        </div>
        <article
          :for={submission <- @assignment.submissions}
          class="rounded-2xl bg-white p-6 shadow-sm dark:bg-base-200"
        >
          <div class="flex items-center justify-between">
            <p class="font-semibold text-emerald-950 dark:text-emerald-100">
              Submitted {Calendar.strftime(submission.inserted_at, "%d %b, %H:%M")}
            </p>
            <.status_badge status={submission.status} />
          </div>
          <audio controls class="mt-4 w-full" src={~p"/recitations/audio/#{submission.id}"}>
            Your browser does not support audio playback.
          </audio>
          <p :if={submission.note} class="mt-3 rounded-lg bg-amber-50 p-3 text-sm text-stone-700">
            Student note: {submission.note}
          </p>
          <%= if submission.status == :submitted do %>
            <.form
              for={@forms[submission.id]}
              id={"review-form-#{submission.id}"}
              phx-submit="review"
              class="mt-5 space-y-3"
            >
              <input type="hidden" name="submission_id" value={submission.id} /><.input
                field={@forms[submission.id][:status]}
                type="select"
                label="Decision"
                options={[{"Approve recitation", "reviewed"}, {"Please repeat", "repeat_required"}]}
              /><.input
                field={@forms[submission.id][:feedback]}
                type="textarea"
                label="Feedback"
                placeholder="Mention the ayah and the correction with gentleness and clarity."
              />
              <.correction_area_selector
                field={@forms[submission.id][:feedback_categories]}
                categories={Recitations.feedback_categories()}
              />
              <.button class="bg-emerald-800 text-white hover:bg-emerald-900">
                Send feedback
              </.button>
            </.form>
          <% else %>
            <p
              :if={submission.feedback}
              class="mt-4 text-sm leading-6 text-stone-600 dark:text-stone-300"
            >
              Tutor feedback: {submission.feedback}
            </p>
            <.feedback_categories
              label="Correction areas"
              categories={submission.feedback_categories}
            />
          <% end %>
        </article>
      </section>
    </Layouts.app>
    """
  end

  defp review_forms(assignment),
    do:
      Map.new(assignment.submissions, fn submission ->
        {submission.id,
         to_form(
           %{
             "status" => Atom.to_string(submission.status),
             "feedback" => submission.feedback || "",
             "feedback_categories" => submission.feedback_categories || []
           },
           as: "review"
         )}
      end)

  defp load_passage(socket, assignment) do
    if connected?(socket) do
      parent = self()

      Task.start(fn ->
        send(parent, {:quran_passage_loaded, UmmahQuran.assigned_passage(assignment)})
      end)
    end

    socket
  end

  defp page_number(page) do
    case Integer.parse(page) do
      {number, ""} -> max(number, 1)
      _ -> 1
    end
  end
end
