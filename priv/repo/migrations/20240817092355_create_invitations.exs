defmodule Horionos.Repo.Migrations.CreateInvitations do
  use Ecto.Migration

  def change do
    create table(:invitations) do
      add :email, :string, null: false
      add :token, :binary, null: false
      add :role, :string, null: false
      add :accepted_at, :utc_datetime
      add :expires_at, :utc_datetime
      add :inviter_id, references(:users, on_delete: :nilify_all)
      add :organization_id, references(:organizations, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:invitations, [:inviter_id])
    create index(:invitations, [:organization_id])
    create unique_index(:invitations, [:email, :organization_id])
    create index(:invitations, [:token])
  end
end
