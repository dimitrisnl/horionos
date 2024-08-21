defmodule Horionos.Orgs.Invitation do
  @moduledoc """
  Invitation schema.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Horionos.Accounts.User
  alias Horionos.Orgs.{MembershipRole, Org}

  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          email: String.t() | nil,
          token: String.t() | nil,
          accepted_at: DateTime.t() | nil,
          role: MembershipRole.t() | nil,
          inviter: User.t() | Ecto.Association.NotLoaded.t() | nil,
          inviter_id: integer() | nil,
          org: Org.t() | Ecto.Association.NotLoaded.t() | nil,
          org_id: integer() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "invitations" do
    field :email, :string
    field :token, :string
    field :role, Ecto.Enum, values: MembershipRole.all()
    field :accepted_at, :utc_datetime
    belongs_to :inviter, User
    belongs_to :org, Org

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:email, :token, :role, :accepted_at, :inviter_id, :org_id])
    |> validate_required([:email, :token, :role, :inviter_id, :org_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_inclusion(:role, MembershipRole.all())
    |> unique_constraint([:email, :org_id], name: :invitations_email_org_id_index)
  end

  @spec generate_token() :: String.t()
  def generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
