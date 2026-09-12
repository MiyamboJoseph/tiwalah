defmodule AppWeb.NotificationLive do
  use AppWeb, :live_view

  alias App.Notifications
  alias App.EmailDeliveryEvents

  def mount(_params, _session, socket) do
    if connected?(socket), do: Notifications.subscribe(socket.assigns.current_scope.user.id)
    {:ok, load_notifications(socket)}
  end

  def handle_info({:notification_created, _id}, socket),
    do: {:noreply, load_notifications(socket)}

  def handle_event("read", %{"id" => id}, socket) do
    case Notifications.mark_read(socket.assigns.current_scope, id) do
      {:ok, notification} ->
        {:noreply,
         socket
         |> load_notifications()
         |> push_navigate(to: notification.path || ~p"/notifications")}

      _ ->
        {:noreply, put_flash(socket, :error, "That notification is unavailable.")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl">
        <p class="text-sm font-bold uppercase tracking-[0.18em] text-amber-700">Stay connected</p>
        <h1 class="mt-2 font-serif text-3xl font-bold text-emerald-950 dark:text-emerald-100">
          Notifications
        </h1>
        <p class="mt-2 text-stone-600">
          Assignments, submissions, feedback, and tutor connections appear here.
        </p>
        <div
          :if={@notifications == []}
          class="mt-6 rounded-2xl border border-dashed border-emerald-900/20 bg-white p-8 text-stone-600"
        >
          You are all caught up.
        </div>
        <div class="mt-6 space-y-3">
          <button
            :for={notification <- @notifications}
            id={"notification-#{notification.id}"}
            phx-click="read"
            phx-value-id={notification.id}
            class={[
              "block w-full rounded-2xl border p-5 text-left shadow-sm transition hover:border-emerald-700",
              if(is_nil(notification.read_at),
                do: "border-amber-300 bg-amber-50",
                else: "border-emerald-900/10 bg-white"
              )
            ]}
          >
            <p class="font-semibold text-emerald-950">{notification.title}</p>
            <p :if={notification.body} class="mt-1 text-sm text-stone-600">{notification.body}</p>
            <p class="mt-2 text-xs text-stone-500">
              {Calendar.strftime(notification.inserted_at, "%d %b, %H:%M")}
            </p>
          </button>
        </div>
        <section :if={@email_delivery_events != []} class="mt-8 rounded-2xl bg-white p-5 shadow-sm">
          <p class="text-sm font-bold uppercase tracking-[0.16em] text-amber-700">Email delivery</p>
          <p class="mt-1 text-sm text-stone-600">
            Your portal always contains the latest updates, even if an email is delayed.
          </p>
          <div class="mt-4 space-y-2">
            <div
              :for={event <- @email_delivery_events}
              class="flex flex-wrap items-center justify-between gap-2 rounded-xl bg-stone-50 px-4 py-3 text-sm"
            >
              <span>{email_event_label(event.event_type)}</span>
              <span class={
                if event.status == :sent,
                  do: "font-semibold text-emerald-800",
                  else: "font-semibold text-rose-700"
              }>
                {if event.status == :sent, do: "Delivered", else: "Delivery delayed"}
              </span>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp load_notifications(socket),
    do:
      assign(socket,
        notifications: Notifications.list(socket.assigns.current_scope),
        unread_count: Notifications.unread_count(socket.assigns.current_scope),
        email_delivery_events: EmailDeliveryEvents.recent(socket.assigns.current_scope)
      )

  defp email_event_label("submission"), do: "New submission alert"
  defp email_event_label("feedback"), do: "Tutor feedback alert"
  defp email_event_label("reminder"), do: "Practice reminder"
  defp email_event_label(_type), do: "Tilawah update"
end
