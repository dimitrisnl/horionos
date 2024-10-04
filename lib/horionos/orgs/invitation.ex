defmodule Horionos.Organizations.Invitation do
  @moduledoc """
  Invitation schema.
  """
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Horionos.Accounts.User
  alias Horionos.Constants
  alias Horionos.Organizations.MembershipRole
  alias Horionos.Organizations.Organization

  @hash_algorithm Constants.hash_algorithm()
  @rand_size Constants.rand_size()
  @invitation_validity_in_days Constants.invitation_validity_in_days()

  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          email: String.t() | nil,
          token: String.t() | nil,
          accepted_at: DateTime.t() | nil,
          expires_at: DateTime.t() | nil,
          role: MembershipRole.t() | nil,
          inviter: User.t() | Ecto.Association.NotLoaded.t() | nil,
          inviter_id: integer() | nil,
          organization: Organization.t() | Ecto.Association.NotLoaded.t() | nil,
          organization_id: integer() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
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

  @doc false
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [
      :email,
      :token,
      :role,
      :accepted_at,
      :expires_at,
      :inviter_id,
      :organization_id
    ])
    |> validate_required([:email, :token, :role, :expires_at, :inviter_id, :organization_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_inclusion(:role, MembershipRole.all())
    |> unique_constraint([:email, :organization_id],
      name: :invitations_email_organization_id_index
    )
  end

  @doc """
  Builds a token and its hash to be delivered to the invitee's email.
  """
  @spec build_invitation_token(User.t(), Organization.t(), String.t(), MembershipRole.t()) ::
          {binary(), map()}
  def build_invitation_token(inviter, organization, email, role) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    expires_at =
      DateTime.utc_now()
      |> DateTime.add(@invitation_validity_in_days, :day)
      |> DateTime.truncate(:second)

    {Base.url_encode64(token, padding: false),
     %{
       email: email,
       token: hashed_token,
       role: role,
       expires_at: expires_at,
       inviter_id: inviter.id,
       organization_id: organization.id
     }}
  end

  @doc """
  Verifies the invitation token.
  """
  @spec verify_invitation_token(binary()) :: {:ok, t()} | {:error, :invalid_token}
  def verify_invitation_token(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from i in __MODULE__,
            where:
              i.token == ^hashed_token and i.expires_at > ^DateTime.utc_now() and
                is_nil(i.accepted_at),
            preload: [:organization, :inviter]

        case Horionos.Repo.one(query) do
          nil -> {:error, :invalid_token}
          invitation -> {:ok, invitation}
        end

      :error ->
        {:error, :invalid_token}
    end
  end

  @doc """
  Returns the inviter's name or "<Deleted user>" if the inviter has been deleted.
  """
  @spec inviter_name(t()) :: String.t()
  def inviter_name(%__MODULE__{inviter: %User{email: email}}), do: email
  def inviter_name(%__MODULE__{inviter: %Ecto.Association.NotLoaded{}}), do: "Unknown"
  def inviter_name(%__MODULE__{inviter: nil}), do: "<Deleted user>"

  @spec expired?(invitation :: t) :: boolean()
  def expired?(invitation) do
    DateTime.compare(DateTime.utc_now(), invitation.expires_at) == :gt
  end
end
