defmodule AppWeb.AdminLive.TutorVerifications do
  use AppWeb, :live_view

  alias App.Accounts

  def mount(_params, _session, socket) do
    {:ok, load_tutors(socket)}
  end

  def handle_event("review_tutor", %{"id" => id, "status" => status}, socket) do
    case decision(status) do
      :invalid ->
        {:noreply, put_flash(socket, :error, "That verification decision is invalid.")}

      status ->
        case Accounts.review_tutor(socket.assigns.current_scope, id, status) do
          {:ok, _tutor} ->
            message = if status == :verified, do: "Tutor verified.", else: "Tutor rejected."
            {:noreply, socket |> put_flash(:info, message) |> load_tutors()}

          _ ->
            {:noreply,
             put_flash(socket, :error, "That verification decision could not be saved.")}
        end
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="rounded-3xl bg-emerald-950 px-6 py-10 text-amber-50 shadow-lg sm:px-10">
        <p class="text-sm font-semibold uppercase tracking-[0.2em] text-amber-300">
          Administrator portal
        </p>
        <h1 class="mt-3 font-serif text-3xl font-bold sm:text-4xl">Tutor verification</h1>
        <p class="mt-3 max-w-2xl text-emerald-100">
          Review teaching background before a tutor can receive student learning requests.
        </p>
      </section>

      <section class="rounded-2xl bg-white p-5 shadow-sm dark:bg-base-200 sm:p-6">
        <div class="flex flex-wrap items-end justify-between gap-3">
          <div>
            <p class="text-sm font-bold uppercase tracking-[0.18em] text-amber-700">Review queue</p>
            <h2 class="mt-1 font-serif text-2xl font-bold text-emerald-950 dark:text-emerald-100">
              Pending tutors
            </h2>
          </div>
          <p class="rounded-full bg-amber-100 px-3 py-1 text-sm font-semibold text-amber-900">
            {@pending_count} awaiting review
          </p>
        </div>

        <p
          :if={@pending_tutors == []}
          class="mt-6 rounded-xl border border-dashed border-emerald-900/20 p-6 text-stone-600"
        >
          There are no tutor profiles awaiting review.
        </p>

        <div :if={@pending_tutors != []} class="mt-6 grid gap-4 lg:grid-cols-2">
          <article
            :for={tutor <- @pending_tutors}
            class="rounded-2xl border border-emerald-900/10 p-5"
          >
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h3 class="font-serif text-xl font-bold text-emerald-950">{tutor_name(tutor)}</h3>
                <p class="mt-1 break-all text-sm text-stone-600">{tutor.email}</p>
              </div>
              <span class="rounded-full bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-900">
                Pending
              </span>
            </div>
            <dl class="mt-5 space-y-3 text-sm text-stone-700">
              <div>
                <dt class="font-semibold text-emerald-950">Teaching background</dt>
                <dd class="mt-1 leading-6">{tutor.tutor_qualification}</dd>
              </div>
              <div class="grid gap-3 sm:grid-cols-2">
                <div>
                  <dt class="font-semibold text-emerald-950">Languages</dt>
                  <dd class="mt-1">{tutor.tutor_languages}</dd>
                </div>
                <div>
                  <dt class="font-semibold text-emerald-950">Format</dt>
                  <dd class="mt-1">{teaching_format(tutor.tutor_teaching_format)}</dd>
                </div>
              </div>
              <div>
                <dt class="font-semibold text-emerald-950">Availability</dt>
                <dd class="mt-1 leading-6">{tutor.tutor_availability}</dd>
              </div>
              <div :if={tutor.tutor_bio}>
                <dt class="font-semibold text-emerald-950">Biography</dt>
                <dd class="mt-1 leading-6">{tutor.tutor_bio}</dd>
              </div>
            </dl>
            <div class="mt-5 flex flex-wrap gap-3 border-t border-emerald-900/10 pt-4">
              <button
                type="button"
                phx-click="review_tutor"
                phx-value-id={tutor.id}
                phx-value-status="verified"
                class="rounded-lg bg-emerald-800 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-900"
              >
                Verify tutor
              </button>
              <button
                type="button"
                phx-click="review_tutor"
                phx-value-id={tutor.id}
                phx-value-status="rejected"
                data-confirm="Reject this tutor profile? They will not be available to students."
                class="rounded-lg border border-rose-300 px-4 py-2 text-sm font-semibold text-rose-800 hover:bg-rose-50"
              >
                Reject
              </button>
            </div>
          </article>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp load_tutors(socket) do
    tutors = Accounts.list_tutors_for_verification(socket.assigns.current_scope)
    pending_tutors = Enum.filter(tutors, &(&1.tutor_verification_status == :pending))

    assign(socket,
      tutors: tutors,
      pending_tutors: pending_tutors,
      pending_count: length(pending_tutors)
    )
  end

  defp tutor_name(tutor) do
    [tutor.first_name, tutor.last_name]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
  end

  defp teaching_format("in_person"), do: "In person"
  defp teaching_format("online"), do: "Online"
  defp teaching_format("both"), do: "Online & in person"
  defp teaching_format(_), do: "Not stated"

  defp decision("verified"), do: :verified
  defp decision("rejected"), do: :rejected
  defp decision(_), do: :invalid
end
