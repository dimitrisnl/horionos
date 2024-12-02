defmodule Horionos.Memberships.Schemas.Membership do
  @moduledoc """
  Membership schema
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Horionos.Accounts.Schemas.User
  alias Horionos.Memberships.Helpers.MembershipRole
  alias Horionos.Organizations.Schemas.Organization

  @type t :: %__MODULE__{
          id: pos_integer(),
          role: MembershipRole.t(),
          user: User.t() | Ecto.Association.NotLoaded.t(),
          user_id: pos_integer(),
          organization: Organization.t() | Ecto.Association.NotLoaded.t(),
          organization_id: pos_integer(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "memberships" do
    field :role, Ecto.Enum, values: MembershipRole.all()

    belongs_to :user, User
    belongs_to :organization, Organization

    timestamps(type: :utc_datetime)
  end

  @spec create_changeset(map()) :: Ecto.Changeset.t()
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:role, :user_id, :organization_id])
    |> validate_required([:role, :user_id, :organization_id])
    |> validate_inclusion(:role, MembershipRole.all())
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:organization_id)
    |> unique_constraint([:user_id, :organization_id],
      name: :memberships_user_id_organization_id_index
    )
  end

  @spec update_role_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_role_changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role])
    |> validate_inclusion(:role, MembershipRole.all())
  end
end
