defmodule Horionos.Repo.Migrations.CreateOrgs do
  use Ecto.Migration

  def change do
    create table(:orgs) do
      add :title, :string

      timestamps(type: :utc_datetime)
    end
  end
end
