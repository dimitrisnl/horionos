defmodule Horionos.Repo.Migrations.CreateAnnouncements do
  use Ecto.Migration

  def change do
    create table(:announcements) do
      add :title, :string
      add :body, :text
      add :organization_id, references(:organizations, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:announcements, [:organization_id])
  end
end
