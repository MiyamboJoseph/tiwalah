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

            <.form
              for={@form}
              id="registration_form"
              phx-submit="save"
              phx-change="validate"
              class="mt-8 space-y-6"
            >
              <fieldset>
                <legend class="text-sm font-semibold text-emerald-950 dark:text-emerald-100">
                  How will you use Tilawah?
                </legend>
                <div class="mt-3 grid gap-3 sm:grid-cols-2">
                  <label class={[
                    "cursor-pointer rounded-2xl border p-4 transition",
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
                    "cursor-pointer rounded-2xl border p-4 transition",
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

              <div class="grid gap-4 sm:grid-cols-2">
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

              <.input
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

              <div class="grid gap-4 sm:grid-cols-2">
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
                field={@form[:email]}
                type="email"
                label="Your email address"
                placeholder="you@example.com"
                autocomplete="email"
                spellcheck="false"
                required
              />

              <div class="grid gap-4 sm:grid-cols-2">
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
              <p class="-mt-3 text-xs text-stone-500 dark:text-stone-400">
                Use at least 12 characters for your password.
              </p>

              <.button
                phx-disable-with="Creating your account..."
                class="w-full bg-emerald-800 py-3 text-white shadow-sm hover:bg-emerald-900"
              >
                Create my account <span aria-hidden="true">→</span>
              </.button>
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

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    if App.AuthRateLimiter.allowed?(:registration, user_params["email"]) do
      register_user(socket, user_params)
    else
      {:noreply, put_flash(socket, :error, "Too many account requests. Please try again later.")}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

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
