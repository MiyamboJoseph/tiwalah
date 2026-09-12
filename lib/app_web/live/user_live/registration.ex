defmodule AppWeb.UserLive.Registration do
  use AppWeb, :live_view

  require Logger

  alias App.Accounts
  alias App.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-5xl overflow-hidden rounded-[2rem] border border-emerald-950/10 bg-white shadow-[0_24px_80px_-35px_rgba(6,78,59,0.55)] dark:bg-base-200 lg:grid lg:grid-cols-[.9fr_1.1fr]">
        <aside class="relative hidden overflow-hidden bg-emerald-950 p-10 text-amber-50 lg:block">
          <div class="absolute -right-16 -top-20 text-[16rem] leading-none text-amber-300/10">۞</div>
          <div class="absolute -bottom-20 -left-16 text-[15rem] leading-none text-amber-300/10">
            ۞
          </div>
          <div class="relative flex h-full flex-col">
            <div class="flex items-center gap-3">
              <span class="grid size-11 place-items-center rounded-xl border border-amber-200/30 bg-emerald-800 text-xl text-amber-200">
                ۞
              </span>
              <span>
                <span class="block font-serif text-xl font-bold">Tilawah</span>
                <span class="block text-[10px] font-bold uppercase tracking-[0.2em] text-amber-300">
                  Recitation circle
                </span>
              </span>
            </div>
            <div class="my-auto py-14">
              <p class="text-sm font-bold uppercase tracking-[0.2em] text-amber-300">
                Begin with intention
              </p>
              <h1 class="mt-5 font-serif text-4xl font-bold leading-tight">
                A more meaningful way to learn Qur’an.
              </h1>
              <p class="mt-5 max-w-sm leading-7 text-emerald-100">
                Share each recitation in a calm, purposeful space and keep every correction close to your learning journey.
              </p>
            </div>
            <div class="border-t border-amber-100/15 pt-6">
              <p class="font-serif text-lg text-amber-100">
                “The best of you are those who learn the Qur’an and teach it.”
              </p>
              <p class="mt-2 text-xs font-bold uppercase tracking-[0.14em] text-emerald-200">
                Sahih al-Bukhari
              </p>
            </div>
          </div>
        </aside>

        <section class="p-7 sm:p-10 lg:p-12">
          <div class="max-w-md">
            <p class="text-xs font-bold uppercase tracking-[0.2em] text-amber-700">
              Create your account
            </p>
            <h1 class="mt-3 font-serif text-3xl font-bold text-emerald-950 dark:text-emerald-100">
              Join the Tilawah circle
            </h1>
            <p class="mt-3 text-sm leading-6 text-stone-600 dark:text-stone-300">
              Create your learning profile and choose a secure password to access your portal.
            </p>

            <div class="mt-7" aria-label="Registration progress">
              <div class="flex items-center justify-between text-xs font-bold uppercase tracking-[0.14em] text-stone-500">
                <span>Step {@step} of 3</span>
                <span>{step_title(@step, @form[:role].value)}</span>
              </div>
              <div class="mt-2 grid grid-cols-3 gap-2">
                <span
                  :for={number <- 1..3}
                  class={[
                    "h-1.5 rounded-full",
                    if(number <= @step, do: "bg-emerald-800", else: "bg-stone-200")
                  ]}
                >
                </span>
              </div>
            </div>

            <.form
              for={@form}
              id="registration_form"
              phx-submit="save"
              phx-change="validate"
              class="mt-7 space-y-5"
            >
              <fieldset :if={@step == 1}>
                <legend class="text-sm font-semibold text-emerald-950 dark:text-emerald-100">
                  How will you use Tilawah?
                </legend>
                <div class="mt-3 grid gap-3 sm:grid-cols-2">
                  <label class={[
                    "cursor-pointer rounded-2xl border p-3.5 transition",
                    @form[:role].value in ["student", :student] &&
                      "border-emerald-700 bg-emerald-50 ring-1 ring-emerald-700 dark:bg-emerald-950/30",
                    !(@form[:role].value in ["student", :student]) &&
                      "border-stone-200 hover:border-emerald-300 dark:border-base-300"
                  ]}>
                    <input
                      type="radio"
                      name={@form[:role].name}
                      value="student"
                      checked={@form[:role].value in ["student", :student]}
                      class="sr-only"
                    />
                    <.icon name="hero-book-open" class="size-5 text-emerald-700" />
                    <span class="mt-3 block font-semibold text-emerald-950 dark:text-emerald-100">
                      I’m a student
                    </span>
                    <span class="mt-1 block text-xs leading-5 text-stone-600 dark:text-stone-300">
                      Practice, record, and receive personal feedback.
                    </span>
                  </label>
                  <label class={[
                    "cursor-pointer rounded-2xl border p-3.5 transition",
                    @form[:role].value in ["tutor", :tutor] &&
                      "border-emerald-700 bg-emerald-50 ring-1 ring-emerald-700 dark:bg-emerald-950/30",
                    !(@form[:role].value in ["tutor", :tutor]) &&
                      "border-stone-200 hover:border-emerald-300 dark:border-base-300"
                  ]}>
                    <input
                      type="radio"
                      name={@form[:role].name}
                      value="tutor"
                      checked={@form[:role].value in ["tutor", :tutor]}
                      class="sr-only"
                    />
                    <.icon name="hero-academic-cap" class="size-5 text-amber-700" />
                    <span class="mt-3 block font-semibold text-emerald-950 dark:text-emerald-100">
                      I’m a tutor
                    </span>
                    <span class="mt-1 block text-xs leading-5 text-stone-600 dark:text-stone-300">
                      Assign portions and guide students with care.
                    </span>
                  </label>
                </div>
              </fieldset>

              <div :if={@step == 1} class="grid gap-4 sm:grid-cols-2">
                <.input
                  field={@form[:first_name]}
                  type="text"
                  label="First name"
                  autocomplete="given-name"
                  required
                  phx-mounted={JS.focus()}
                />
                <.input
                  field={@form[:last_name]}
                  type="text"
                  label="Last name"
                  autocomplete="family-name"
                  required
                />
              </div>

              <section
                :if={@step == 2 && @form[:role].value in ["tutor", :tutor]}
                class="rounded-2xl border border-amber-300/70 bg-amber-50/70 p-4"
              >
                <p class="text-sm font-bold text-emerald-950">Tutor profile</p>
                <p class="mt-1 text-xs leading-5 text-stone-600">
                  This helps students make an informed decision before accepting your connection request.
                </p>
                <div class="mt-4 space-y-4">
                  <.input
                    field={@form[:tutor_qualification]}
                    type="textarea"
                    label="Qualification or Qur’an teaching background"
                    placeholder="For example: Ijāzah in Hafs ʿan ʿĀṣim, or madrasa teaching experience"
                    required
                  />
                  <div class="grid gap-4 sm:grid-cols-2">
                    <.input
                      field={@form[:tutor_experience_years]}
                      type="number"
                      min="0"
                      max="80"
                      label="Years teaching (optional)"
                    />
                    <.input
                      field={@form[:tutor_teaching_format]}
                      type="select"
                      label="Teaching format"
                      prompt="Select a format"
                      options={[{"Online", "online"}, {"In person", "in_person"}, {"Both", "both"}]}
                      required
                    />
                  </div>
                  <.input
                    field={@form[:tutor_student_limit]}
                    type="number"
                    min="1"
                    max="500"
                    label="Maximum students in your circle"
                  />
                  <p class="-mt-2 text-xs text-stone-500">
                    You can accept requests until this limit is reached.
                  </p>
                  <.input
                    field={@form[:tutor_languages]}
                    type="text"
                    label="Teaching languages"
                    placeholder="For example: English, Arabic, Bemba"
                    required
                  />
                  <.input
                    field={@form[:tutor_availability]}
                    type="textarea"
                    label="Availability"
                    placeholder="For example: Weekdays 18:00–21:00 CAT"
                    required
                  />
                  <.input
                    field={@form[:tutor_bio]}
                    type="textarea"
                    label="Short biography (optional)"
                    placeholder="Tell students a little about your teaching approach."
                  />
                </div>
              </section>

              <.input
                :if={@step == 1}
                field={@form[:gender]}
                type="select"
                label="Gender"
                prompt="Select your gender"
                options={[
                  {"Female", "female"},
                  {"Male", "male"},
                  {"Prefer not to say", "prefer_not_to_say"}
                ]}
                required
              />

              <div
                :if={
                  (@step == 2 && @form[:role].value in ["student", :student]) ||
                    (@step == 3 && @form[:role].value in ["tutor", :tutor])
                }
                class="grid gap-4 sm:grid-cols-2"
              >
                <.input
                  field={@form[:location]}
                  type="text"
                  label="Location"
                  autocomplete="address-level2"
                  placeholder="City, country"
                  required
                />
                <.input
                  field={@form[:phone_number]}
                  type="tel"
                  label="Phone number"
                  autocomplete="tel"
                  placeholder="+260 …"
                  required
                />
              </div>

              <.input
                :if={
                  (@step == 2 && @form[:role].value in ["student", :student]) ||
                    (@step == 3 && @form[:role].value in ["tutor", :tutor])
                }
                field={@form[:time_zone]}
                type="select"
                label="Time zone"
                options={[
                  {"Central Africa Time (CAT)", "Africa/Lusaka"},
                  {"East Africa Time (EAT)", "Africa/Nairobi"},
                  {"West Africa Time (WAT)", "Africa/Lagos"},
                  {"Arabia Standard Time", "Asia/Riyadh"},
                  {"Pakistan Standard Time", "Asia/Karachi"}
                ]}
                required
              />

              <.input
                :if={@step == 3}
                field={@form[:email]}
                type="email"
                label="Your email address"
                placeholder="you@example.com"
                autocomplete="email"
                spellcheck="false"
                required
              />

              <div :if={@step == 3} class="grid gap-4 sm:grid-cols-2">
                <.input
                  field={@form[:password]}
                  type="password"
                  label="Password"
                  autocomplete="new-password"
                  required
                />
                <.input
                  field={@form[:password_confirmation]}
                  type="password"
                  label="Confirm password"
                  autocomplete="new-password"
                  required
                />
              </div>
              <p :if={@step == 3} class="-mt-3 text-xs text-stone-500 dark:text-stone-400">
                Use at least 8 characters for your password.
              </p>

              <.input
                :if={@step == 3}
                field={@form[:terms_accepted]}
                type="checkbox"
                label="I agree to Tilawah’s Terms of Service and Privacy Notice."
                required
              />
              <p :if={@step == 3} class="-mt-3 text-xs leading-5 text-stone-500 dark:text-stone-400">
                Read the
                <.link navigate={~p"/terms"} class="font-semibold text-emerald-800 underline">
                  Terms of Service
                </.link>
                and <.link navigate={~p"/privacy"} class="font-semibold text-emerald-800 underline">Privacy Notice</.link>. Your profile and contact details are used only to run your recitation circle and connect you through student-approved learning relationships.
              </p>

              <div class="flex flex-wrap items-center justify-between gap-3 border-t border-emerald-900/10 pt-4">
                <button
                  :if={@step > 1}
                  type="submit"
                  name="wizard_action"
                  value="back"
                  formnovalidate
                  class="rounded-lg px-4 py-3 text-sm font-semibold text-emerald-800 hover:bg-emerald-50"
                >
                  ← Back
                </button>
                <span :if={@step == 1}></span>
                <.button
                  :if={@step < 3}
                  name="wizard_action"
                  value="next"
                  class="bg-emerald-800 px-5 py-3 text-white shadow-sm hover:bg-emerald-900"
                >
                  Continue →
                </.button>
                <.button
                  :if={@step == 3}
                  name="wizard_action"
                  value="create"
                  phx-disable-with="Creating your account..."
                  class="bg-emerald-800 px-5 py-3 text-white shadow-sm hover:bg-emerald-900"
                >
                  Create my account →
                </.button>
              </div>
            </.form>

            <p class="mt-6 text-center text-sm text-stone-600 dark:text-stone-300">
              Already part of Tilawah?
              <.link
                navigate={~p"/users/log-in"}
                class="font-semibold text-emerald-800 hover:underline"
              >
                Sign in
              </.link>
            </p>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: AppWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(params, _session, socket) do
    role = if params["role"] == "tutor", do: :tutor, else: :student

    changeset =
      Accounts.change_user_registration(%User{}, %{role: role}, validate_unique: false)

    {:ok,
     socket
     |> assign(step: 1, registration_params: %{"role" => Atom.to_string(role)})
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("save", %{"wizard_action" => "next", "user" => params}, socket) do
    params = merged_params(socket, params)

    if step_valid?(socket.assigns.step, params) do
      {:noreply,
       socket
       |> assign(step: socket.assigns.step + 1, registration_params: params)
       |> assign_form(build_changeset(params))}
    else
      {:noreply,
       socket |> assign(registration_params: params) |> assign_form(validation_changeset(params))}
    end
  end

  def handle_event("save", %{"wizard_action" => "back", "user" => params}, socket) do
    params = merged_params(socket, params)

    {:noreply,
     socket
     |> assign(step: socket.assigns.step - 1, registration_params: params)
     |> assign_form(build_changeset(params))}
  end

  def handle_event("save", %{"wizard_action" => "create", "user" => params}, socket) do
    user_params = merged_params(socket, params)

    if App.AuthRateLimiter.allowed?(:registration, user_params["email"]) do
      register_user(socket, user_params)
    else
      {:noreply, put_flash(socket, :error, "Too many account requests. Please try again later.")}
    end
  end

  def handle_event("save", %{"user" => params}, socket) do
    user_params = merged_params(socket, params)

    if App.AuthRateLimiter.allowed?(:registration, user_params["email"]) do
      register_user(socket, user_params)
    else
      {:noreply, put_flash(socket, :error, "Too many account requests. Please try again later.")}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    params = merged_params(socket, user_params)

    {:noreply,
     socket |> assign(registration_params: params) |> assign_form(build_changeset(params))}
  end

  defp merged_params(socket, params) do
    merged = Map.merge(socket.assigns.registration_params, params)

    if socket.assigns.step == 3 and not Map.has_key?(params, "terms_accepted") do
      Map.delete(merged, "terms_accepted")
    else
      merged
    end
  end

  defp build_changeset(params) do
    Accounts.change_user_registration(%User{}, params, validate_unique: false)
    |> User.password_changeset(params, hash_password: false)
  end

  defp validation_changeset(params), do: build_changeset(params) |> Map.put(:action, :validate)

  defp step_valid?(step, params) do
    changeset = build_changeset(params)
    fields = step_fields(step, Map.get(params, "role"))

    Enum.all?(fields, fn field -> not Keyword.has_key?(changeset.errors, field) end)
  end

  defp step_fields(1, _role), do: [:role, :first_name, :last_name, :gender]

  defp step_fields(2, "tutor") do
    [
      :tutor_qualification,
      :tutor_teaching_format,
      :tutor_languages,
      :tutor_availability,
      :tutor_student_limit
    ]
  end

  defp step_fields(2, _role), do: [:location, :phone_number, :time_zone]

  defp step_fields(3, "tutor"),
    do: [
      :location,
      :phone_number,
      :time_zone,
      :email,
      :password,
      :password_confirmation,
      :terms_accepted
    ]

  defp step_fields(3, _role), do: [:email, :password, :password_confirmation, :terms_accepted]

  defp step_title(1, _role), do: "About you"
  defp step_title(2, "tutor"), do: "Tutor profile"
  defp step_title(2, _role), do: "Contact details"
  defp step_title(3, _role), do: "Secure access"

  defp register_user(socket, user_params) do
    case Accounts.register_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Your account is ready. Please sign in with your email and password."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
