defmodule AppWeb.StudentRecitationLive.New do
  use AppWeb, :live_view

  alias App.Recitations
  alias App.Recitations.AudioStorage
  alias App.UmmahApi.Learning
  alias App.UmmahApi.Quran, as: UmmahQuran

  def mount(%{"assignment_id" => assignment_id}, _session, socket) do
    scope = socket.assigns.current_scope

    case {scope.user.role, Recitations.get_assignment(scope, assignment_id)} do
      {:student, assignment} when not is_nil(assignment) ->
        {:ok,
         socket
         |> assign(assignment: assignment, form: to_form(%{"note" => ""}, as: "submission"))
         |> assign(
           quran_passage: :loading,
           passage_page: 1,
           word_by_word: %{},
           reciter_audio: %{}
         )
         |> load_passage(assignment)
         |> allow_upload(:audio,
           accept: ~w(.webm .mp3 .wav .m4a .ogg),
           max_entries: 1,
           max_file_size: 25_000_000,
           auto_upload: true,
           progress: &handle_upload_progress/3
         )}

      {:tutor, _assignment} ->
        {:ok,
         socket
         |> put_flash(:error, "Recording submissions are available in the student portal.")
         |> push_navigate(to: ~p"/tutor")}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "That assignment is unavailable.")
         |> push_navigate(to: ~p"/dashboard")}
    end
  end

  def handle_event("submit", %{"submission" => params}, socket) do
    case uploaded_audio(socket) do
      {:ok, audio_path} ->
        case Recitations.create_submission(
               socket.assigns.current_scope,
               socket.assigns.assignment.id,
               Map.put(params, "audio_path", audio_path)
             ) do
          {:ok, _submission} ->
            {:noreply,
             socket
             |> put_flash(:info, "Your recitation was sent to your tutor.")
             |> push_navigate(to: ~p"/dashboard")}

          {:error, changeset} ->
            {:noreply, assign(socket, form: to_form(changeset, as: "submission"))}
        end

      :error ->
        {:noreply,
         put_flash(socket, :error, "Please attach one audio recording before submitting.")}

      :storage_error ->
        {:noreply,
         put_flash(socket, :error, "Your recording could not be saved. Please try again.")}
    end
  end

  def handle_event("validate", %{"submission" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "submission"))}
  end

  # Kept as a compatibility handler for a browser that still has a previously
  # compiled recorder hook loaded. Recorder diagnostics are client-side only.
  def handle_event("recording_debug", _params, socket), do: {:noreply, socket}

  def handle_event("cancel-upload", %{"ref" => ref}, socket),
    do: {:noreply, cancel_upload(socket, :audio, ref)}

  def handle_event("paginate_passage", %{"page" => page}, socket) do
    socket =
      socket
      |> assign(passage_page: page_number(page), word_by_word: %{}, reciter_audio: %{})
      |> load_words()
      |> load_reciter_audio()

    {:noreply, socket}
  end

  def handle_info({:quran_passage_loaded, result}, socket) do
    {:noreply, socket |> assign(quran_passage: result) |> load_words() |> load_reciter_audio()}
  end

  def handle_info({:word_by_word_loaded, words}, socket),
    do: {:noreply, assign(socket, word_by_word: words)}

  def handle_info({:reciter_audio_loaded, clips}, socket),
    do: {:noreply, assign(socket, reciter_audio: clips)}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-7xl">
        <.link navigate={~p"/dashboard"} class="text-sm font-semibold text-emerald-800">
          ← Back to my portal
        </.link>
        <div class="mt-5 rounded-3xl bg-white p-6 shadow-sm dark:bg-base-200 sm:p-8">
          <p class="text-sm font-bold uppercase tracking-[0.18em] text-amber-700">
            Juz {@assignment.juz_number}
          </p>
          <h1 class="mt-2 font-serif text-3xl font-bold text-emerald-950 dark:text-emerald-100">
            Record {@assignment.title}
          </h1>
          <p class="mt-2 text-stone-600 dark:text-stone-300">
            {@assignment.surah_name}, ayah {@assignment.ayah_from}–{@assignment.ayah_to}. Find a quiet place, begin with istiʿādhah and basmalah where appropriate, then record your best attempt.
          </p>
          <.repeat_guidance
            :if={@assignment.status == :repeat_required}
            submission={latest_repeat_submission(@assignment)}
            audio_src={~p"/recitations/feedback-audio/#{latest_repeat_submission(@assignment).id}"}
          />
          <div class="mt-6">
            <.quran_passage
              passage={@quran_passage}
              page={@passage_page}
              on_page_change="paginate_passage"
              word_by_word={@word_by_word}
              reciter_audio={@reciter_audio}
            />
          </div>
          <.form
            for={@form}
            id="recitation-submission-form"
            phx-change="validate"
            phx-submit="submit"
            class="mt-8 space-y-5"
          >
            <div class="rounded-2xl border border-dashed border-emerald-800/30 bg-emerald-50/50 p-5 dark:bg-base-300">
              <label class="block text-sm font-semibold text-emerald-950 dark:text-emerald-100">
                Audio recording
              </label>
              <div
                id="audio-recorder"
                phx-hook="AudioRecorder"
                class="mt-3 flex flex-wrap items-center gap-3"
              >
                <button
                  type="button"
                  data-record
                  class="rounded-lg bg-rose-700 px-4 py-2 text-sm font-semibold text-white"
                >
                  Start recording
                </button>
                <button
                  type="button"
                  data-pause
                  disabled
                  class="rounded-lg border border-amber-600 px-4 py-2 text-sm font-semibold text-amber-800 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  Pause recording
                </button>
                <button
                  type="button"
                  data-stop
                  disabled
                  class="rounded-lg border border-emerald-800 px-4 py-2 text-sm font-semibold text-emerald-900 disabled:opacity-50 dark:text-emerald-100"
                >
                  Stop & attach
                </button>
                <span
                  data-recording-timer
                  aria-label="Recording duration"
                  class="rounded-full bg-rose-50 px-3 py-1 font-mono text-sm font-semibold tabular-nums text-rose-800"
                >
                  00:00
                </span>
                <span data-status class="text-sm text-stone-600">Or upload a recording below.</span>
                <.live_file_input upload={@uploads.audio} class="basis-full text-sm" />
                <p class="basis-full text-xs text-stone-600">
                  Record in the browser or upload WEBM, MP3, WAV, M4A, or OGG (up to 25 MB).
                </p>
              </div>
              <div
                :for={entry <- @uploads.audio.entries}
                class="mt-3 flex flex-wrap items-center justify-between gap-2 rounded-lg bg-white px-3 py-2 text-sm dark:bg-base-200"
              >
                <div class="min-w-0">
                  <span class="block truncate">{entry.client_name}</span>
                  <p :if={!entry.done?} class="mt-1 text-xs text-stone-500">
                    Uploading… {entry.progress}%
                  </p>
                  <p
                    :for={error <- upload_errors(@uploads.audio, entry)}
                    class="mt-1 text-xs text-rose-700"
                  >
                    {upload_error_message(error)}
                  </p>
                </div>
                <button
                  type="button"
                  phx-click="cancel-upload"
                  phx-value-ref={entry.ref}
                  class="shrink-0 text-rose-700"
                >
                  Remove
                </button>
              </div>
            </div>
            <.input
              field={@form[:note]}
              type="textarea"
              label="Note for your tutor (optional)"
              placeholder="For example: I found ayah 12 difficult."
            />
            <.button
              class="w-full bg-emerald-800 text-white hover:bg-emerald-900"
              disabled={Enum.any?(@uploads.audio.entries, &(not &1.done?))}
              phx-disable-with="Submitting..."
            >
              Send recitation for review
            </.button>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp uploaded_audio(socket) do
    case consume_uploaded_entries(socket, :audio, fn %{path: path}, entry ->
           case AudioStorage.store(path, entry.client_name) do
             {:ok, storage_key} -> {:ok, storage_key}
             {:error, reason} -> {:ok, {:error, reason}}
           end
         end) do
      [audio_path] when is_binary(audio_path) -> {:ok, audio_path}
      [{:error, _reason}] -> :storage_error
      _ -> :error
    end
  end

  defp latest_repeat_submission(assignment) do
    assignment.submissions
    |> Enum.filter(&(&1.status == :repeat_required))
    |> Enum.max_by(& &1.inserted_at)
  end

  defp handle_upload_progress(:audio, _entry, socket), do: {:noreply, socket}

  defp upload_error_message(:too_large), do: "The recording must be 25 MB or smaller."
  defp upload_error_message(:not_accepted), do: "Use WEBM, MP3, WAV, M4A, or OGG audio."
  defp upload_error_message(_), do: "The recording could not be uploaded."

  defp load_passage(socket, assignment) do
    if connected?(socket) do
      parent = self()

      Task.start(fn ->
        send(parent, {:quran_passage_loaded, UmmahQuran.assigned_passage(assignment)})
      end)
    end

    socket
  end

  defp load_words(%{assigns: %{quran_passage: {:ok, passage}, assignment: assignment}} = socket) do
    if connected?(socket) do
      parent = self()
      page = socket.assigns.passage_page
      verses = Enum.slice(passage.verses, 5 * (page - 1), 5)

      Task.start(fn ->
        with {:ok, surah_number} <- App.Quran.surah_number(assignment.surah_name) do
          send(parent, {:word_by_word_loaded, Learning.word_by_word(surah_number, verses)})
        end
      end)
    end

    socket
  end

  defp load_words(socket), do: socket

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

  defp page_number(page) do
    case Integer.parse(page) do
      {number, ""} -> max(number, 1)
      _ -> 1
    end
  end
end
