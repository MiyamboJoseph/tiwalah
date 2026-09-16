defmodule AppWeb.AdminLive.TutorVerifications do
  use AppWeb, :live_view

  alias App.Accounts

  def mount(_params, _session, socket) do
    {:ok, load_tutors(socket, 1)}
  end

  def handle_event("paginate_tutors", %{"page" => page}, socket),
    do: {:noreply, load_tutors(socket, page)}

  def handle_event("review_tutor", %{"_id" => id, "status" => status} = params, socket) do
    case decision(status) do
      :invalid ->
        {:noreply, put_flash(socket, :error, "That verification decision is invalid.")}

      status ->
        case Accounts.review_tutor(socket.assigns.current_scope, id, status, params["reason"]) do
          {:ok, _tutor} ->
            message = if status == :verified, do: "Tutor verified.", else: "Tutor rejected."
            {:noreply, socket |> put_flash(:info, message) |> load_tutors(socket.assigns.page)}

          {:error, :rejection_reason_required} ->
            {:noreply,
             put_flash(socket, :error, "Please give the tutor a clear reason for the decision.")}

          _ ->
            {:noreply,
             put_flash(socket, :error, "That verification decision could not be saved.")}
        end
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.navigation active={:tutors} />
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
                phx-value-_id={tutor.id}
                phx-value-status="verified"
                class="rounded-lg bg-emerald-800 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-900"
              >
                Verify tutor
              </button>
            </div>
            <form class="mt-4 border-t border-emerald-900/10 pt-4" phx-submit="review_tutor">
              <input type="hidden" name="_id" value={tutor.id} />
              <input type="hidden" name="status" value="rejected" />
              <label
                class="text-sm font-semibold text-emerald-950"
                for={"rejection-reason-#{tutor.id}"}
              >
                Reason if declining
              </label>
              <textarea
                id={"rejection-reason-#{tutor.id}"}
                name="reason"
                required
                rows="2"
                class="mt-2 w-full rounded-lg border border-stone-300 px-3 py-2 text-sm"
                placeholder="Explain what needs to be improved or supplied."
              ></textarea>
              <button
                type="submit"
                data-confirm="Decline this tutor profile and send the stated guidance?"
                class="mt-2 rounded-lg border border-rose-300 px-4 py-2 text-sm font-semibold text-rose-800 hover:bg-rose-50"
              >
                Decline with guidance
              </button>
            </form>
          </article>
        </div>
        <.pagination
          page={@page}
          total_pages={@total_pages}
          total_entries={@pending_count}
          item_label="pending tutors"
          on_change="paginate_tutors"
        />
      </section>
    </Layouts.app>
    """
  end

  defp load_tutors(socket, page) do
    pagination = Accounts.paginate_tutors_for_verification(socket.assigns.current_scope, page)

    assign(socket,
      pending_tutors: pagination.entries,
      pending_count: pagination.total_entries,
      page: pagination.page,
      total_pages: pagination.total_pages
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
