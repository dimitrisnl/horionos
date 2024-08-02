defmodule Horionos.Repo.Migrations.CreateOrgs do
  use Ecto.Migration

  def change do
    create table(:orgs) do
      add :title, :string
      add :slug, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:orgs, [:slug])
  end
end
