defmodule Horionos.Orgs.Org do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          title: String.t(),
          memberships: [Horionos.Memberships.Membership.t()],
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "orgs" do
    field :title, :string

    has_many :memberships, Horionos.Memberships.Membership

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(org, attrs) do
    org
    |> cast(attrs, [:title])
    |> validate_required([:title])
  end
end
