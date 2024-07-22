# General application configuration
import Config

config :horionos,
  ecto_repos: [Horionos.Repo],
  generators: [timestamp_type: :utc_datetime],
  # Emails
  from_email: "contact@horionos.com",
  from_name: "Horionos",
  # Tokens
  reset_password_validity_in_days: 1,
  confirm_validity_in_days: 7,
  change_email_validity_in_days: 7,
  session_validity_in_days: 60

# Oban configuration
config :horionos, Oban,
  repo: Horionos.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [emails: 10, default: 10]

# Configures the endpoint
config :horionos, HorionosWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: HorionosWeb.ErrorHTML, json: HorionosWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Horionos.PubSub,
  live_view: [signing_salt: "S6Z3/glq"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :horionos, Horionos.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  horionos: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.0",
  horionos: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
