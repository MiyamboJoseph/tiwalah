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

# UmmahAPI is used server-side for Qur'an learning content. No API key is required.
config :app, :ummah_api, base_url: System.get_env("UMMAH_API_BASE_URL") || "https://ummahapi.com"

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

# Configure SMTP delivery. Set these environment variables before starting Phoenix:
# SMTP_RELAY, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD, MAIL_FROM_EMAIL, MAIL_FROM_NAME.
# When they are absent, development safely falls back to Swoosh's local mailbox.
smtp_relay = System.get_env("SMTP_RELAY")
smtp_username = System.get_env("SMTP_USERNAME")
smtp_password = System.get_env("SMTP_PASSWORD")

if smtp_relay && smtp_username && smtp_password do
  smtp_port = String.to_integer(System.get_env("SMTP_PORT") || "465")
  smtp_uses_implicit_ssl? = smtp_port == 465

  config :app, App.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: smtp_relay,
    username: smtp_username,
    password: smtp_password,
    port: smtp_port,
    ssl: smtp_uses_implicit_ssl?,
    tls: if(smtp_uses_implicit_ssl?, do: :never, else: :always),
    auth: :always,
    tls_options: [
      versions: [:"tlsv1.2", :"tlsv1.3"],
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(smtp_relay),
      depth: 99,
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ],
    sockopts: [
      :binary,
      packet: :line,
      keepalive: true,
      active: false,
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(smtp_relay),
      depth: 99,
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]

  config :app,
    mail_from: {
      System.get_env("MAIL_FROM_NAME") || "Tilawah Recitation Circle",
      System.get_env("MAIL_FROM_EMAIL") || smtp_username
    }
else
  config :app, App.Mailer, adapter: Swoosh.Adapters.Local
  config :app, mail_from: {"Tilawah Recitation Circle", "no-reply@tilawah.local"}
end

config :app, Oban,
  repo: App.Repo,
  queues: [mailers: 10, maintenance: 2],
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"0 * * * *", App.Workers.DailyPracticeReminder},
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
