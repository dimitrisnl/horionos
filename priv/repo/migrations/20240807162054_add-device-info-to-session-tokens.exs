defmodule Horionos.Repo.Migrations.AddDeviceInfoToSessionTokens do
  use Ecto.Migration

  def change do
    alter table(:session_tokens) do
      add :device, :string, default: "Unknown"
      add :os, :string, default: "Unknown"
      add :browser, :string, default: "Unknown"
      add :browser_version, :string, default: ""
    end
  end
end
