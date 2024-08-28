defmodule Horionos.Repo.Migrations.CreateOrganizations do
  use Ecto.Migration

  def change do
    create table(:organizations) do
      add :title, :string
      add :slug, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:organizations, [:slug])
  end
end
