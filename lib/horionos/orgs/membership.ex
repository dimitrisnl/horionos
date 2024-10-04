defmodule Horionos.Organizations.Membership do
  @moduledoc """
  Schema and changeset for managing memberships between users and organizations.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Horionos.Accounts.User
  alias Horionos.Organizations.MembershipRole
  alias Horionos.Organizations.Organization

  @type t :: %__MODULE__{
          id: integer() | nil,
          role: MembershipRole.t() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          user_id: integer() | nil,
          organization: Organization.t() | Ecto.Association.NotLoaded.t(),
          organization_id: integer() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "memberships" do
    field :role, Ecto.Enum, values: MembershipRole.all()

    belongs_to :user, User
    belongs_to :organization, Organization

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a membership.

  ## Parameters

    - `membership`: The membership struct to change
    - `attrs`: The attributes to apply to the membership

  ## Returns

    A changeset.
  """
  @spec changeset(t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  #
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :user_id, :organization_id])
    |> validate_required([:role, :user_id, :organization_id])
    |> validate_inclusion(:role, MembershipRole.all())
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:organization_id)
    |> unique_constraint([:user_id, :organization_id],
      name: :memberships_user_id_organization_id_index
    )
  end

  @doc """
  Creates a changeset for updating a membership's role.

  ## Parameters

    - membership: The membership struct to change
    - new_role: The new role to assign

  ## Returns

    A changeset.
  """
  @spec update_role_changeset(t(), MembershipRole.t()) :: Ecto.Changeset.t()
  #
  def update_role_changeset(membership, new_role) do
    membership
    |> change(role: new_role)
    |> validate_inclusion(:role, MembershipRole.all())
  end
end
