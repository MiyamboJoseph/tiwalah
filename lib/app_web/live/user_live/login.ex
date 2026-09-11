defmodule AppWeb.UserLive.Login do
  use AppWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto grid max-w-5xl overflow-hidden rounded-[2rem] border border-emerald-950/10 bg-white shadow-[0_24px_80px_-35px_rgba(6,78,59,0.55)] dark:bg-base-200 lg:grid-cols-[.88fr_1.12fr]">
        <aside class="relative hidden overflow-hidden bg-emerald-950 p-10 text-amber-50 lg:block">
          <div class="absolute -right-16 -top-20 text-[16rem] leading-none text-amber-300/10">۞</div>
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
            <div class="my-auto py-16">
              <p class="text-sm font-bold uppercase tracking-[0.2em] text-amber-300">Welcome back</p>
              <h1 class="mt-5 font-serif text-4xl font-bold leading-tight">
                Return to your recitation journey.
              </h1>
              <p class="mt-5 max-w-sm leading-7 text-emerald-100">
                Your next portion, your tutor’s guidance, and your progress are waiting for you.
              </p>
            </div>
            <p class="border-t border-amber-100/15 pt-6 text-sm leading-6 text-emerald-100">
              “Recite the Qur’an, for it will come as an intercessor for its companions.”
            </p>
          </div>
        </aside>
        <section class="p-7 sm:p-10 lg:p-12">
          <div class="max-w-md">
            <p class="text-xs font-bold uppercase tracking-[0.2em] text-amber-700">Secure access</p>
            <h1 class="mt-3 font-serif text-3xl font-bold text-emerald-950 dark:text-emerald-100">
              Welcome to Tilawah
            </h1>
            <p class="mt-3 text-sm leading-6 text-stone-600 dark:text-stone-300">
              <%= if @current_scope do %>
                Please reauthenticate to continue with a sensitive account action.
              <% else %>
                Sign in securely with the email address and password you used when creating your account.
              <% end %>
            </p>
            <.form
              :let={f}
              for={@form}
              id="login_form_password"
              action={~p"/users/log-in"}
              phx-submit="submit_password"
              phx-trigger-action={@trigger_submit}
              class="mt-7 space-y-5"
            >
              <.input
                readonly={!!@current_scope}
                field={f[:email]}
                type="email"
                label="Email address"
                autocomplete="username"
                spellcheck="false"
                required
                phx-mounted={JS.focus()}
              />
              <.input
                field={@form[:password]}
                type="password"
                label="Password"
                autocomplete="current-password"
                required
              />
              <.button class="w-full bg-emerald-800 py-3 text-white shadow-sm hover:bg-emerald-900">
                Sign in <span aria-hidden="true">→</span>
              </.button>
            </.form>
            <p
              :if={!@current_scope}
              class="mt-7 text-center text-sm text-stone-600 dark:text-stone-300"
            >
              New to Tilawah?
              <.link
                navigate={~p"/users/register"}
                class="font-semibold text-emerald-800 hover:underline"
              >
                Create an account
              </.link>
            </p>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
