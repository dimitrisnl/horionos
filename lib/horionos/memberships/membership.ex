defmodule Horionos.Memberships.Membership do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          role: String.t(),
          user: Horionos.Accounts.User.t(),
          org: Horionos.Orgs.Org.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "memberships" do
    field :role, :string

    belongs_to :user, Horionos.Accounts.User
    belongs_to :org, Horionos.Orgs.Org

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role])
    |> validate_required([:role])
  end
end
