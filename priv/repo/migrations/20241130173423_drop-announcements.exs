defmodule :"Elixir.Horionos.Repo.Migrations.Drop-announcements" do
  use Ecto.Migration

  def change do
    drop table(:announcements)
  end
end
