defmodule AppWeb.TutorLive.Review do
  use AppWeb, :live_view

  alias App.Recitations
  alias App.Recitations.AudioStorage
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
             repeat_submission_ids: repeat_submission_ids(assignment),
             quran_passage: :loading,
             passage_page: 1,
             show_all_passage: false
           )
           |> allow_upload(:tutor_audio,
             accept: ~w(.webm .mp3 .wav .m4a .ogg),
             max_entries: 1,
             max_file_size: 25_000_000,
             auto_upload: true
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
        {:noreply,
         assign(socket,
           assignment: assignment,
           forms: review_forms(assignment),
           repeat_submission_ids: repeat_submission_ids(assignment)
         )}
    end
  end

  def handle_info({:quran_passage_loaded, result}, socket),
    do: {:noreply, assign(socket, quran_passage: result)}

  def handle_event("paginate_passage", %{"page" => page}, socket),
    do: {:noreply, assign(socket, passage_page: page_number(page))}

  def handle_event("toggle_passage_view", _params, socket),
    do:
      {:noreply,
       assign(socket, show_all_passage: !socket.assigns.show_all_passage, passage_page: 1)}

  def handle_event(
        "set_review_decision",
        %{"submission_id" => id, "review" => %{"status" => status}},
        socket
      ) do
    submission_id = String.to_integer(id)

    repeat_submission_ids =
      if status == "repeat_required" do
        MapSet.put(socket.assigns.repeat_submission_ids, submission_id)
      else
        MapSet.delete(socket.assigns.repeat_submission_ids, submission_id)
      end

    {:noreply, assign(socket, repeat_submission_ids: repeat_submission_ids)}
  end

  def handle_event("review", %{"submission_id" => id, "review" => params}, socket) do
    with {:ok, params} <- attach_tutor_audio(socket, params),
         {:ok, _} <- Recitations.review_submission(socket.assigns.current_scope, id, params) do
      assignment =
        Recitations.get_assignment!(socket.assigns.current_scope, socket.assigns.assignment.id)

      {:noreply,
       socket
       |> assign(
         assignment: assignment,
         forms: review_forms(assignment),
         repeat_submission_ids: repeat_submission_ids(assignment)
       )
       |> put_flash(:info, "Feedback sent to the student.")}
    else
      {:error, :tutor_audio} ->
        {:noreply,
         put_flash(socket, :error, "The tutor audio could not be saved. Please try again.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "That submission is unavailable.")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(
           forms:
             Map.put(
               socket.assigns.forms,
               String.to_integer(id),
               to_form(changeset, as: "review")
             )
         )
         |> put_flash(:error, "Please complete the required repeat guidance fields.")}
    end
  end

  def handle_event("cancel-tutor-audio", %{"ref" => ref}, socket),
    do: {:noreply, cancel_upload(socket, :tutor_audio, ref)}

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
          <div class="flex items-center justify-between gap-4">
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
              phx-change="set_review_decision"
              phx-submit="review"
              class="mt-5 space-y-4"
            >
              <input type="hidden" name="submission_id" value={submission.id} />
              <.input
                field={@forms[submission.id][:status]}
                type="select"
                label="Decision"
                options={[{"Approve recitation", "reviewed"}, {"Please repeat", "repeat_required"}]}
              />
              <.input
                field={@forms[submission.id][:feedback]}
                type="textarea"
                label="Tutor guidance"
                placeholder="Mention the ayah and correction with gentleness and clarity. Required for a repeat."
              />
              <div
                :if={submission.id in @repeat_submission_ids}
                class="rounded-xl border border-amber-300 bg-amber-50 p-4"
              >
                <p class="font-semibold text-amber-950">Repeat guidance</p>
                <p class="mt-1 text-sm text-stone-700">
                  Complete these fields when requesting a repeat so the student knows exactly how to practise.
                </p>
                <div class="mt-4 grid gap-3 sm:grid-cols-2">
                  <.input
                    field={@forms[submission.id][:repeat_ayah_from]}
                    type="number"
                    min="1"
                    label="First ayah to repeat"
                  /><.input
                    field={@forms[submission.id][:repeat_ayah_to]}
                    type="number"
                    min="1"
                    label="Last ayah to repeat"
                  />
                </div>
                <.input
                  field={@forms[submission.id][:repeat_instruction]}
                  type="textarea"
                  label="Practice instruction"
                  placeholder="For example: Listen twice, repeat each ayah five times, then submit a new recording."
                  class="mt-3 w-full textarea"
                />
                <.input
                  field={@forms[submission.id][:repeat_due_date]}
                  type="date"
                  label="Revised deadline (optional)"
                  class="mt-3 w-full input"
                />
                <div class="mt-3">
                  <label class="block text-sm font-medium text-stone-700">
                    Tutor audio example <span class="text-stone-400">(optional)</span>
                  </label>
                  <div
                    id={"tutor-audio-recorder-#{submission.id}"}
                    phx-hook="AudioRecorder"
                    class="mt-3 flex flex-wrap items-center gap-3 rounded-xl border border-emerald-800/20 bg-white p-3"
                  >
                    <button
                      type="button"
                      data-record
                      class="rounded-lg bg-emerald-800 px-3 py-2 text-sm font-semibold text-white hover:bg-emerald-900"
                    >
                      Record example
                    </button>
                    <button
                      type="button"
                      data-stop
                      disabled
                      class="rounded-lg border border-emerald-800 px-3 py-2 text-sm font-semibold text-emerald-800 disabled:cursor-not-allowed disabled:opacity-50"
                    >
                      Stop & attach
                    </button>
                    <span
                      data-recording-timer
                      aria-label="Recording duration"
                      class="rounded-full bg-emerald-50 px-3 py-1 font-mono text-sm font-semibold tabular-nums text-emerald-800"
                    >
                      00:00
                    </span>
                    <span data-status class="text-sm text-stone-600">
                      Record here or upload an example below.
                    </span>
                  </div>
                  <.live_file_input upload={@uploads.tutor_audio} class="mt-2 block w-full text-sm" />
                  <p class="mt-1 text-xs text-stone-500">WEBM, MP3, WAV, M4A, or OGG up to 25 MB.</p>
                  <div
                    :for={entry <- @uploads.tutor_audio.entries}
                    class="mt-2 flex items-center justify-between text-sm"
                  >
                    <span>{entry.client_name} — {entry.progress}%</span><button
                      type="button"
                      phx-click="cancel-tutor-audio"
                      phx-value-ref={entry.ref}
                      class="text-rose-700"
                    >Remove</button>
                  </div>
                </div>
              </div>
              <.correction_area_selector
                field={@forms[submission.id][:feedback_categories]}
                categories={Recitations.feedback_categories()}
              />
              <.button
                class="bg-emerald-800 text-white hover:bg-emerald-900"
                disabled={Enum.any?(@uploads.tutor_audio.entries, &(not &1.done?))}
              >
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
            <.repeat_guidance
              submission={submission}
              audio_src={~p"/recitations/feedback-audio/#{submission.id}"}
            />
          <% end %>
        </article>
      </section>
    </Layouts.app>
    """
  end

  defp attach_tutor_audio(socket, params) do
    case consume_uploaded_entries(socket, :tutor_audio, fn %{path: path}, entry ->
           case AudioStorage.store(path, entry.client_name) do
             {:ok, storage_key} -> {:ok, storage_key}
             {:error, _reason} -> {:ok, :storage_error}
           end
         end) do
      [] ->
        {:ok, params}

      [audio_path] when is_binary(audio_path) ->
        {:ok, Map.put(params, "tutor_audio_path", audio_path)}

      _ ->
        {:error, :tutor_audio}
    end
  end

  defp review_forms(assignment) do
    Map.new(assignment.submissions, fn submission ->
      {submission.id,
       to_form(
         %{
           "status" => Atom.to_string(submission.status),
           "feedback" => submission.feedback || "",
           "feedback_categories" => submission.feedback_categories || [],
           "repeat_ayah_from" => submission.repeat_ayah_from,
           "repeat_ayah_to" => submission.repeat_ayah_to,
           "repeat_instruction" => submission.repeat_instruction || "",
           "repeat_due_date" => submission.repeat_due_date
         },
         as: "review"
       )}
    end)
  end

  defp repeat_submission_ids(assignment) do
    assignment.submissions
    |> Enum.filter(&(&1.status == :repeat_required))
    |> MapSet.new(& &1.id)
  end

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
