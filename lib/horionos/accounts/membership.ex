defmodule Horionos.Accounts.Membership do
  use Ecto.Schema
  import Ecto.Changeset

  schema "memberships" do
    field :role, :string

    belongs_to :user, Horionos.Accounts.User
    belongs_to :org, Horionos.Accounts.Org

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role])
    |> validate_required([:role])
  end
end
