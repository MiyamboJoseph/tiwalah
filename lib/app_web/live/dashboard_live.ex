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

      :admin ->
        {:ok, push_navigate(socket, to: ~p"/admin/tutors")}
    end
  end

  def handle_info({:recitation_changed, _event, _assignment_id}, socket) do
    {:noreply, load_dashboard(socket)}
  end

  def handle_event("paginate_assignments", %{"page" => page}, socket) do
    {:noreply, load_dashboard(socket, page)}
  end

  def handle_event("request_tutor", %{"tutor_request" => %{"tutor_id" => tutor_id}}, socket) do
    send_tutor_request(tutor_id, socket)
  end

  def handle_event("accept_tutor_request", %{"id" => id}, socket) do
    case Recitations.accept_tutor_request(socket.assigns.current_scope, id) do
      {:ok, _connection} ->
        {:noreply, socket |> put_flash(:info, "Tutor request accepted.") |> load_dashboard()}

      _ ->
        {:noreply, put_flash(socket, :error, "That tutor request is no longer available.")}
    end
  end

  def handle_event("decline_tutor_request", %{"id" => id}, socket) do
    case Recitations.decline_tutor_request(socket.assigns.current_scope, id) do
      {:ok, _connection} ->
        {:noreply, socket |> put_flash(:info, "Tutor request declined.") |> load_dashboard()}

      _ ->
        {:noreply, put_flash(socket, :error, "That tutor request is no longer available.")}
    end
  end

  def handle_event("disconnect_tutor", %{"id" => id}, socket) do
    case Recitations.disconnect_tutor_student(socket.assigns.current_scope, id) do
      {:ok, _connection} ->
        {:noreply, socket |> put_flash(:info, "Tutor connection ended.") |> load_dashboard()}

      _ ->
        {:noreply, put_flash(socket, :error, "That tutor connection is no longer available.")}
    end
  end

  defp send_tutor_request(tutor_id, socket) do
    case Recitations.request_tutor_connection(socket.assigns.current_scope, tutor_id) do
      {:ok, _connection} ->
        {:noreply,
         socket
         |> put_flash(:info, "Learning request sent. The tutor will review it before connecting.")
         |> load_dashboard()}

      {:error, :tutor_not_found} ->
        {:noreply, put_flash(socket, :error, "Select a verified tutor to continue.")}

      {:error, :already_requested} ->
        {:noreply,
         put_flash(socket, :info, "Your request is already awaiting this tutor’s response.")}

      {:error, :tutor_invited} ->
        {:noreply,
         put_flash(
           socket,
           :info,
           "This tutor has already invited you. Review the invitation below."
         )}

      {:error, :tutor_unavailable} ->
        {:noreply,
         put_flash(
           socket,
           :info,
           "This tutor is not currently available to accept learning requests."
         )}

      {:error, :already_connected} ->
        {:noreply, put_flash(socket, :info, "You are already connected with this tutor.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Your learning request could not be sent.")}
    end
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
        <.metric title="Active portions" value={@assignment_counts.active} icon="hero-book-open" />
        <.metric title="Ready to record" value={@pending} icon="hero-microphone" />
        <.metric title="Approved" value={@reviewed} icon="hero-check-badge" />
      </section>
      <section class="rounded-2xl border border-emerald-900/10 bg-white p-5 shadow-sm dark:bg-base-200">
        <div class="flex flex-wrap items-end justify-between gap-3">
          <div>
            <p class="text-sm font-bold uppercase tracking-[0.18em] text-amber-700">Find a teacher</p>
            <h2 class="mt-1 font-serif text-2xl font-bold text-emerald-950 dark:text-emerald-100">
              Request Qur’an guidance
            </h2>
            <p class="mt-1 text-sm text-stone-600 dark:text-stone-300">
              Choose a tutor and send a learning request. They must accept before any portion is assigned.
            </p>
          </div>
          <.form for={@tutor_request_form} phx-submit="request_tutor" class="w-full sm:max-w-md">
            <.input
              field={@tutor_request_form[:tutor_id]}
              type="select"
              label="Choose a verified Qur’an teacher"
              prompt="Select a tutor"
              options={Enum.map(@tutor_directory, &{tutor_option(&1), &1.id})}
              required
            />
            <.button
              disabled={@tutor_directory == []}
              class="mt-3 w-full bg-emerald-800 text-white hover:bg-emerald-900 disabled:cursor-not-allowed disabled:opacity-50"
            >
              Request to learn
            </.button>
          </.form>
        </div>
        <p :if={@tutor_directory == []} class="mt-4 text-sm text-stone-600 dark:text-stone-300">
          No verified tutors are available yet. Please check again soon.
        </p>
      </section>
      <section :if={@requested_tutors != []} class="rounded-2xl border border-sky-200 bg-sky-50 p-5">
        <p class="text-sm font-bold uppercase tracking-[0.16em] text-sky-800">
          Requests awaiting a tutor
        </p>
        <div class="mt-3 flex flex-wrap gap-3">
          <div :for={request <- @requested_tutors} class="rounded-xl bg-white px-4 py-3 shadow-sm">
            <p class="font-semibold text-emerald-950">{tutor_name(request.tutor)}</p>
            <p class="mt-1 text-sm text-stone-600">Awaiting their response.</p>
          </div>
        </div>
      </section>
      <section class="rounded-2xl bg-white p-6 shadow-sm dark:bg-base-200">
        <div class="flex flex-wrap items-end justify-between gap-3">
          <div>
            <p class="text-sm font-bold uppercase tracking-[0.18em] text-amber-700">Your progress</p>
            <h2 class="mt-1 font-serif text-2xl font-bold text-emerald-950 dark:text-emerald-100">
              Learning journey
            </h2>
          </div>
          <p class="text-3xl font-bold text-emerald-900">{@progress.approval_rate}%</p>
        </div>
        <div class="mt-4 grid gap-4 sm:grid-cols-3">
          <p class="text-sm text-stone-600">
            <span class="block text-2xl font-bold text-emerald-950">
              {@progress.total_submissions}
            </span>
            recordings submitted
          </p>
          <p class="text-sm text-stone-600">
            <span class="block text-2xl font-bold text-emerald-950">{@progress.approved}</span>
            approved
          </p>
          <p class="text-sm text-stone-600">
            <span class="block text-2xl font-bold text-emerald-950">{@progress.repeats}</span>
            repeats requested
          </p>
        </div>
        <.feedback_categories
          label="Most frequent correction areas"
          categories={Enum.map(@progress.focus_areas, &elem(&1, 0))}
        />
      </section>
      <section :if={@tutor_requests != []} class="rounded-2xl border border-amber-300 bg-amber-50 p-5">
        <p class="text-sm font-bold uppercase tracking-[0.16em] text-amber-800">Tutor invitations</p>
        <p class="mt-1 text-sm text-stone-700">
          Choose which teacher may assign and review your recitation.
        </p>
        <div class="mt-4 space-y-3">
          <div
            :for={request <- @tutor_requests}
            class="flex flex-wrap items-center justify-between gap-3 rounded-xl bg-white p-4 shadow-sm"
          >
            <div>
              <p class="font-semibold text-emerald-950">{tutor_name(request.tutor)}</p>
              <p :if={request.tutor.tutor_qualification} class="mt-1 text-sm leading-6 text-stone-700">
                {request.tutor.tutor_qualification}
              </p>
              <div class="mt-2 flex flex-wrap gap-2 text-xs font-semibold">
                <span
                  :if={request.tutor.tutor_languages}
                  class="rounded-full bg-emerald-50 px-2.5 py-1 text-emerald-900"
                >
                  {request.tutor.tutor_languages}
                </span>
                <span
                  :if={request.tutor.tutor_teaching_format}
                  class="rounded-full bg-amber-100 px-2.5 py-1 text-amber-900"
                >
                  {teaching_format(request.tutor.tutor_teaching_format)}
                </span>
              </div>
              <p :if={request.tutor.tutor_availability} class="mt-2 text-xs text-stone-600">
                Availability: {request.tutor.tutor_availability}
              </p>
              <p :if={request.tutor.tutor_bio} class="mt-2 text-sm leading-6 text-stone-600">
                {request.tutor.tutor_bio}
              </p>
              <p class="mt-2 text-xs font-semibold text-stone-500">
                {tutor_verification_label(request.tutor.tutor_verification_status)}
              </p>
            </div>
            <div class="flex shrink-0 flex-wrap gap-2">
              <button
                id={"accept-tutor-#{request.id}"}
                type="button"
                phx-click="accept_tutor_request"
                phx-value-id={request.id}
                class="rounded-lg bg-emerald-800 px-3 py-2 text-sm font-semibold text-white hover:bg-emerald-900"
              >
                Accept tutor
              </button>
              <button
                id={"decline-tutor-#{request.id}"}
                type="button"
                phx-click="decline_tutor_request"
                phx-value-id={request.id}
                class="rounded-lg border border-rose-300 px-3 py-2 text-sm font-semibold text-rose-800 hover:bg-rose-50"
              >
                Decline
              </button>
            </div>
          </div>
        </div>
      </section>
      <section :if={@active_tutors != []} class="rounded-2xl bg-white p-5 shadow-sm dark:bg-base-200">
        <p class="text-sm font-bold uppercase tracking-[0.18em] text-amber-700">Your tutors</p>
        <div class="mt-3 flex flex-wrap gap-3">
          <div
            :for={{connection_id, tutor} <- @active_tutors}
            class="rounded-xl border border-emerald-900/10 p-3"
          >
            <p class="font-semibold text-emerald-950">{tutor_name(tutor)}</p>
            <button
              type="button"
              phx-click="disconnect_tutor"
              phx-value-id={connection_id}
              data-confirm="End this tutor connection? Existing recitation history will remain available."
              class="mt-2 text-sm font-semibold text-rose-700 hover:underline"
            >
              End connection
            </button>
          </div>
        </div>
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
              <.repeat_guidance
                :if={assignment.status == :repeat_required}
                submission={latest_repeat_submission(assignment)}
                audio_src={~p"/recitations/feedback-audio/#{latest_repeat_submission(assignment).id}"}
              />
            </:detail>
            <:action>
              <%= if assignment.status in [:assigned, :repeat_required] do %>
                <.link
                  navigate={~p"/recitations/new/#{assignment.id}"}
                  class="font-semibold text-emerald-800 hover:underline"
                >
                  {if assignment.status == :repeat_required,
                    do: "Record revised recitation →",
                    else: "Record recitation →"}
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
    |> Enum.filter(&(&1.status == status))
    |> Enum.max_by(& &1.inserted_at, fn -> nil end)
    |> case do
      nil -> []
      submission -> submission.feedback_categories || []
    end
  end

  defp latest_feedback_categories(_assignment), do: []

  defp latest_repeat_submission(assignment) do
    assignment.submissions
    |> Enum.filter(&(&1.status == :repeat_required))
    |> Enum.max_by(& &1.inserted_at)
  end

  defp tutor_name(tutor) do
    [tutor.first_name, tutor.last_name]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
    |> case do
      "" -> tutor.email
      name -> name
    end
  end

  defp tutor_option(tutor) do
    details =
      [
        tutor.tutor_languages,
        tutor.tutor_teaching_format && teaching_format(tutor.tutor_teaching_format)
      ]
      |> Enum.reject(&(&1 in [nil, ""]))

    case details do
      [] -> tutor_name(tutor)
      _ -> "#{tutor_name(tutor)} · #{Enum.join(details, " · ")}"
    end
  end

  defp teaching_format("in_person"), do: "In person"
  defp teaching_format("online"), do: "Online"
  defp teaching_format("both"), do: "Online & in person"
  defp teaching_format(_format), do: "Teaching format not stated"

  defp tutor_verification_label(:verified), do: "Tutor profile verified"
  defp tutor_verification_label(:pending), do: "Credentials submitted · verification pending"
  defp tutor_verification_label(:rejected), do: "Verification needs attention"
  defp tutor_verification_label(_status), do: "Tutor profile"

  defp load_dashboard(socket, page \\ nil) do
    page = page || Map.get(socket.assigns, :page, 1)
    assignment_page = Recitations.paginate_assignments(socket.assigns.current_scope, page)

    assign(socket,
      assignments: assignment_page.entries,
      assignment_counts: Recitations.assignment_counts(socket.assigns.current_scope),
      page: assignment_page.page,
      total_pages: assignment_page.total_pages,
      tutor_requests: Recitations.list_pending_tutor_requests(socket.assigns.current_scope),
      requested_tutors: Recitations.list_pending_requested_tutors(socket.assigns.current_scope),
      tutor_directory: Recitations.list_tutor_directory(socket.assigns.current_scope),
      tutor_request_form: to_form(%{"tutor_id" => ""}, as: "tutor_request"),
      active_tutors: Recitations.list_active_tutors(socket.assigns.current_scope),
      progress: Recitations.student_progress(socket.assigns.current_scope)
    )
  end
end
