defmodule Horionos.Repo.Migrations.CreateMemberships do
  use Ecto.Migration

  def change do
    create table(:memberships) do
      add :role, :string
      add :organization_id, references(:organizations, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:memberships, [:organization_id])
    create index(:memberships, [:user_id])
  end
end
