# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# This project uses JavaScript hooks in assets/app.js rather than colocated hook files.
config :phoenix_live_view, :colocated_js, disable_symlink_warning: true

config :app, :scopes,
  user: [
    default: true,
    module: App.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: App.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :app,
  ecto_repos: [App.Repo],
  generators: [timestamp_type: :utc_datetime]

# UmmahAPI is used server-side for Qur'an learning content. An API key is optional,
# but increases available request capacity. Never expose it to browser JavaScript.
config :app, :ummah_api,
  base_url: System.get_env("UMMAH_API_BASE_URL") || "https://ummahapi.com",
  api_key: System.get_env("UMMAH_API_KEY") || "",
  default_reciter: System.get_env("UMMAH_RECITER") || "Mishary Alafasy"

# Configure the endpoint
config :app, AppWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: AppWeb.ErrorHTML, json: AppWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: App.PubSub,
  live_view: [signing_salt: "vdYDIEEl"]

# Gmail SMTP for local development and production. Credentials remain in the
# environment, never in this repository. When they are absent, development
# falls back to Swoosh's local mailbox.
smtp_username = System.get_env("SMTP_USERNAME") || "miyamboyusuf@gmail.com"
smtp_password = System.get_env("SMTP_PASSWORD") || "zypk qxam lkes szou"

if smtp_username && smtp_password do
  config :app, App.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: "smtp.gmail.com",
    username: smtp_username,
    password: smtp_password,
    port: 587,
    ssl: false,
    tls: :always,
    auth: :always,
    retries: 3,
    timeout: 30_000,
    tls_options: [
      verify: :verify_peer,
      cacertfile: Path.expand("../deps/castore/priv/cacerts.pem", __DIR__),
      server_name_indication: ~c"smtp.gmail.com",
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ],
      depth: 3,
      versions: [:"tlsv1.2", :"tlsv1.3"]
    ]

  config :app,
    mail_from: {
      System.get_env("MAIL_FROM_NAME") || "Tilawah Recitation Circle",
      System.get_env("MAIL_FROM_EMAIL") || smtp_username
    }
else
  config :app, App.Mailer, adapter: Swoosh.Adapters.Local
  config :app, mail_from: {"Tilawah Recitation Circle", "miyamboyusuf@gmail.com"}
end

config :app, Oban,
  repo: App.Repo,
  queues: [mailers: 10, maintenance: 2],
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"*/15 * * * *", App.Workers.DailyPracticeReminder},
       {"30 2 * * *", App.Workers.AudioCleanupWorker},
       {"0 3 * * *", App.Workers.AudioBackupWorker}
     ]}
  ]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  app: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# M4A is normally served as audio/mp4, but it is not bundled in this
# project's MIME registry. Register it so LiveView can safely accept it.
config :mime, :types, %{
  "audio/mp4" => ["m4a"],
  "audio/ogg" => ["ogg"]
}

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  app: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
