defmodule Horionos.Repo do
  use Ecto.Repo,
    otp_app: :horionos,
    adapter: Ecto.Adapters.Postgres
end
