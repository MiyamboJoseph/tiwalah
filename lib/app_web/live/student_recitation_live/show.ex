defmodule AppWeb.StudentRecitationLive.Show do
  use AppWeb, :live_view

  alias App.Recitations
  alias App.UmmahApi.Quran, as: UmmahQuran
  alias App.UmmahApi.Learning

  def mount(%{"assignment_id" => assignment_id}, _session, socket) do
    scope = socket.assigns.current_scope

    case {scope.user.role, Recitations.get_assignment(scope, assignment_id)} do
      {:student, assignment} when not is_nil(assignment) ->
        if connected?(socket), do: Recitations.subscribe_student(scope.user.id)

        {:ok,
         socket
         |> assign(
           assignment: assignment,
           quran_passage: :loading,
           passage_page: 1,
           reciter_audio: %{},
           active_reciter_ayah: nil
         )
         |> load_passage(assignment)}

      {:tutor, _} ->
        {:ok, push_navigate(socket, to: ~p"/tutor")}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "That recitation is unavailable.")
         |> push_navigate(to: ~p"/dashboard")}
    end
  end

  def handle_info({:recitation_changed, _event, assignment_id}, socket) do
    case Recitations.get_assignment(socket.assigns.current_scope, assignment_id) do
      nil -> {:noreply, push_navigate(socket, to: ~p"/dashboard")}
      assignment -> {:noreply, assign(socket, assignment: assignment)}
    end
  end

  def handle_info({:quran_passage_loaded, result}, socket),
    do: {:noreply, socket |> assign(quran_passage: result) |> load_reciter_audio()}

  def handle_info({:reciter_audio_loaded, clips}, socket),
    do: {:noreply, assign(socket, reciter_audio: clips)}

  def handle_event("paginate_passage", %{"page" => page}, socket) do
    {:noreply,
     socket
     |> assign(passage_page: page_number(page), reciter_audio: %{}, active_reciter_ayah: nil)
     |> load_reciter_audio()}
  end

  def handle_event("toggle_reciter_audio", %{"ayah" => ayah}, socket) do
    {:noreply, assign(socket, active_reciter_ayah: toggled_ayah(socket, ayah))}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <.link navigate={~p"/dashboard"} class="text-sm font-semibold text-emerald-800">
          ← Back to my portal
        </.link>
        <section class="mt-5 rounded-3xl bg-white p-6 shadow-sm dark:bg-base-200 sm:p-8">
          <p class="text-sm font-bold uppercase tracking-[0.18em] text-amber-700">
            Juz {@assignment.juz_number}
          </p>
          <h1 class="mt-2 font-serif text-3xl font-bold text-emerald-950 dark:text-emerald-100">
            {@assignment.title}
          </h1>
          <p class="mt-2 text-stone-600 dark:text-stone-300">
            {@assignment.surah_name}, ayah {@assignment.ayah_from}–{@assignment.ayah_to}
          </p>
          <div class="mt-4"><.status_badge status={@assignment.status} /></div>
          <div class="mt-3"><.due_date_label due_date={@assignment.due_date} /></div>
        </section>
        <div class="mt-6">
          <.quran_passage
            passage={@quran_passage}
            page={@passage_page}
            on_page_change="paginate_passage"
            reciter_audio={@reciter_audio}
            active_reciter_ayah={@active_reciter_ayah}
            on_audio_toggle="toggle_reciter_audio"
          />
        </div>
        <section class="mt-6 space-y-5">
          <article
            :for={submission <- @assignment.submissions}
            class="rounded-2xl bg-white p-6 shadow-sm dark:bg-base-200"
          >
            <div class="flex flex-wrap items-center justify-between gap-3 sm:gap-4">
              <p class="font-semibold text-emerald-950 dark:text-emerald-100">
                Submitted {Calendar.strftime(submission.inserted_at, "%d %b, %H:%M")}
              </p>
              <.submission_deadline_label
                due_date={@assignment.due_date}
                submitted_at={submission.inserted_at}
              />
              <.status_badge status={submission.status} />
            </div>
            <audio controls class="mt-4 w-full" src={~p"/recitations/audio/#{submission.id}"}>
              Your browser does not support audio playback.
            </audio>
            <p :if={submission.note} class="mt-4 rounded-lg bg-amber-50 p-3 text-sm text-stone-700">
              Your note: {submission.note}
            </p>
            <div
              :if={submission.feedback || submission.feedback_categories != []}
              class="mt-5 rounded-xl border border-emerald-900/10 bg-emerald-50/50 p-4"
            >
              <p class="font-semibold text-emerald-950">Tutor guidance</p>
              <p :if={submission.feedback} class="mt-2 leading-6 text-stone-700">
                {submission.feedback}
              </p>
              <.feedback_categories
                label="Correction areas"
                categories={submission.feedback_categories}
              />
              <.repeat_guidance
                submission={submission}
                audio_src={~p"/recitations/feedback-audio/#{submission.id}"}
              />
            </div>
          </article>
          <div
            :if={@assignment.submissions == []}
            class="rounded-2xl border border-dashed border-emerald-900/20 bg-white p-8 text-stone-600 dark:bg-base-200"
          >
            No recording has been submitted yet.
          </div>
        </section>
      </div>
    </Layouts.app>
    """
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

  defp load_reciter_audio(
         %{assigns: %{quran_passage: {:ok, passage}, assignment: assignment}} = socket
       ) do
    if connected?(socket) do
      parent = self()
      page = socket.assigns.passage_page
      verses = Enum.slice(passage.verses, 5 * (page - 1), 5)

      Task.start(fn ->
        with {:ok, surah_number} <- App.Quran.surah_number(assignment.surah_name) do
          send(parent, {:reciter_audio_loaded, Learning.reciter_audio(surah_number, verses)})
        end
      end)
    end

    socket
  end

  defp load_reciter_audio(socket), do: socket

  defp toggled_ayah(socket, value) do
    case Integer.parse(value) do
      {ayah, ""} when socket.assigns.active_reciter_ayah == ayah -> nil
      {ayah, ""} -> ayah
      _ -> nil
    end
  end
end
