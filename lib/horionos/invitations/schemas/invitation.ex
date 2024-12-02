defmodule Horionos.Invitations.Schemas.Invitation do
  @moduledoc """
  Invitation schema.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Horionos.Accounts.Schemas.User
  alias Horionos.Memberships.Helpers.MembershipRole
  alias Horionos.Organizations.Schemas.Organization

  @type t :: %__MODULE__{
          id: pos_integer(),
          email: String.t(),
          token: String.t(),
          accepted_at: DateTime.t() | nil,
          expires_at: DateTime.t(),
          role: MembershipRole.t(),
          inviter: User.t() | Ecto.Association.NotLoaded.t(),
          inviter_id: pos_integer(),
          organization: Organization.t() | Ecto.Association.NotLoaded.t(),
          organization_id: pos_integer(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "invitations" do
    field :email, :string
    field :token, :string
    field :role, Ecto.Enum, values: MembershipRole.all()
    field :accepted_at, :utc_datetime
    field :expires_at, :utc_datetime
    belongs_to :inviter, User
    belongs_to :organization, Organization

    timestamps(type: :utc_datetime)
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :email,
      :token,
      :role,
      :expires_at,
      :inviter_id,
      :organization_id
    ])
    |> validate_required([:email, :token, :role, :expires_at, :inviter_id, :organization_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_inclusion(:role, MembershipRole.all())
    |> foreign_key_constraint(:inviter_id)
    |> foreign_key_constraint(:organization_id)
    |> unique_constraint([:email, :organization_id],
      name: :invitations_email_organization_id_index
    )
  end

  def accept_changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:accepted_at])
    |> validate_required([:accepted_at])
  end

  @spec inviter_name(t()) :: String.t()
  def inviter_name(%__MODULE__{inviter: %User{full_name: full_name}}), do: full_name
  def inviter_name(%__MODULE__{inviter: %Ecto.Association.NotLoaded{}}), do: "Unknown"
  def inviter_name(%__MODULE__{inviter: nil}), do: "<Deleted user>"

  @spec expired?(invitation :: t) :: boolean()
  def expired?(invitation) do
    DateTime.compare(DateTime.utc_now(), invitation.expires_at) == :gt
  end
end
