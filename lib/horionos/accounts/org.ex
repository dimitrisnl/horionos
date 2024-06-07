defmodule Horionos.Accounts.Org do
  use Ecto.Schema
  import Ecto.Changeset

  schema "orgs" do
    field :title, :string

    has_many :memberships, Horionos.Accounts.Membership

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(org, attrs) do
    org
    |> cast(attrs, [:title])
    |> validate_required([:title])
  end
end
