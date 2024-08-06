defmodule Horionos.Repo.Migrations.AddLockingToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :locked_at, :utc_datetime
    end

    create index(:users, [:locked_at])
  end

  def down do
    drop index(:users, [:locked_at])

    alter table(:users) do
      remove :locked_at
    end
  end
end
