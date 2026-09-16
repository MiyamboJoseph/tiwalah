defmodule AppWeb.UserLive.Settings do
  use AppWeb, :live_view

  on_mount {AppWeb.UserAuth, :require_sudo_mode}

  alias App.Accounts
  alias App.Accounts.Scope

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="text-center">
        <.header>
          Account Settings
          <:subtitle>Manage your account email address and password settings</:subtitle>
        </.header>
      </div>

      <.form for={@email_form} id="email_form" phx-submit="update_email" phx-change="validate_email">
        <.input
          field={@email_form[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          spellcheck="false"
          required
        />
        <.button variant="primary" phx-disable-with="Changing...">Change Email</.button>
      </.form>

      <div class="divider" />

      <.form
        for={@practice_location_form}
        id="practice_location_form"
        phx-submit="update_practice_location"
        phx-change="validate_practice_location"
      >
        <h2 class="text-lg font-semibold text-emerald-950 dark:text-emerald-100">
          Practice reminder location
        </h2>
        <p class="mt-1 text-sm text-stone-600 dark:text-stone-300">
          Save an approximate location to receive due-practice reminders shortly after Maghrib. It is optional and is shared with UmmahAPI only to calculate prayer times.
        </p>
        <div
          id="settings-practice-location"
          phx-hook="LocationPicker"
          class="mt-4 rounded-xl border border-emerald-900/10 bg-emerald-50/50 p-4"
        >
          <button
            type="button"
            data-use-location
            class="rounded-lg border border-emerald-800 px-3 py-2 text-sm font-semibold text-emerald-900 hover:bg-emerald-100"
          >
            Use approximate location
          </button>
          <p data-location-status class="mt-2 text-xs text-stone-600">
            Your browser will ask permission before sharing coordinates with Tilawah.
          </p>
          <input
            type="hidden"
            name={@practice_location_form[:latitude].name}
            value={@practice_location_form[:latitude].value}
            data-latitude
          />
          <input
            type="hidden"
            name={@practice_location_form[:longitude].name}
            value={@practice_location_form[:longitude].value}
            data-longitude
          />
        </div>
        <div class="mt-4 grid gap-4 sm:grid-cols-2">
          <.input
            field={@practice_location_form[:location]}
            type="text"
            label="Location"
            autocomplete="address-level2"
            required
          />
          <.input
            field={@practice_location_form[:time_zone]}
            type="select"
            label="Time zone"
            options={time_zone_options()}
            required
          />
        </div>
        <.button variant="primary" phx-disable-with="Saving…">Save reminder location</.button>
        <button
          :if={@current_scope.user.latitude && @current_scope.user.longitude}
          type="button"
          phx-click="remove_practice_location"
          data-confirm="Remove your saved prayer reminder location? You will return to the standard reminder time."
          class="ml-3 text-sm font-semibold text-rose-700 hover:underline"
        >
          Remove saved location
        </button>
      </.form>

      <div class="divider" />

      <.form
        for={@password_form}
        id="password_form"
        action={~p"/users/update-password"}
        method="post"
        phx-change="validate_password"
        phx-submit="update_password"
        phx-trigger-action={@trigger_submit}
      >
        <input
          name={@password_form[:email].name}
          type="hidden"
          id="hidden_user_email"
          spellcheck="false"
          value={@current_email}
        />
        <.input
          field={@password_form[:password]}
          type="password"
          label="New password"
          autocomplete="new-password"
          spellcheck="false"
          required
        />
        <.input
          field={@password_form[:password_confirmation]}
          type="password"
          label="Confirm new password"
          autocomplete="new-password"
          spellcheck="false"
        />
        <.button variant="primary" phx-disable-with="Saving...">
          Save Password
        </.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:practice_location_form, to_form(Accounts.change_user_practice_location(user)))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        case Accounts.deliver_user_update_email_instructions(
               Ecto.Changeset.apply_action!(changeset, :insert),
               user.email,
               &url(~p"/users/settings/confirm-email/#{&1}")
             ) do
          {:ok, _email} ->
            info = "A link to confirm your email change has been sent to the new address."
            {:noreply, socket |> put_flash(:info, info)}

          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(
               :error,
               "We could not send the confirmation email. Please try again later."
             )}
        end

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("validate_practice_location", %{"user" => params}, socket) do
    form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_practice_location(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, practice_location_form: form)}
  end

  def handle_event("update_practice_location", %{"user" => params}, socket) do
    case Accounts.update_user_practice_location(socket.assigns.current_scope.user, params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(current_scope: Scope.for_user(user))
         |> assign(practice_location_form: to_form(Accounts.change_user_practice_location(user)))
         |> put_flash(:info, "Your practice reminder location was saved.")}

      {:error, changeset} ->
        {:noreply, assign(socket, practice_location_form: to_form(changeset, action: :validate))}
    end
  end

  def handle_event("remove_practice_location", _params, socket) do
    case Accounts.clear_user_practice_location(socket.assigns.current_scope.user) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(current_scope: Scope.for_user(user))
         |> assign(practice_location_form: to_form(Accounts.change_user_practice_location(user)))
         |> put_flash(:info, "Your saved prayer reminder location was removed.")}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "We could not remove your location. Please try again.")}
    end
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end

  defp time_zone_options do
    [
      {"Central Africa Time (CAT)", "Africa/Lusaka"},
      {"East Africa Time (EAT)", "Africa/Nairobi"},
      {"West Africa Time (WAT)", "Africa/Lagos"},
      {"Arabia Standard Time", "Asia/Riyadh"},
      {"Pakistan Standard Time", "Asia/Karachi"}
    ]
  end
end
