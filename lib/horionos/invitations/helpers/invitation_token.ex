defmodule Horionos.Invitations.Helpers.InvitationToken do
  @moduledoc """
  Handles invitation token generation, verification, and related stuff.
  """

  alias Horionos.Accounts.Schemas.User
  alias Horionos.Constants
  alias Horionos.Memberships.Helpers.MembershipRole
  alias Horionos.Organizations.Schemas.Organization
  alias Horionos.Services.TokenHash

  @invitation_validity_in_days Constants.invitation_validity_in_days()

  @spec generate(User.t(), Organization.t(), String.t(), MembershipRole.t()) ::
          {binary(), map()}
  def generate(inviter, organization, email, role) do
    {raw_token, hashed_token} = TokenHash.generate()
    encoded_token = TokenHash.encode(raw_token)

    expires_at =
      DateTime.utc_now()
      |> DateTime.add(@invitation_validity_in_days, :day)
      |> DateTime.truncate(:second)

    {
      encoded_token,
      %{
        email: email,
        token: hashed_token,
        role: role,
        expires_at: expires_at,
        inviter_id: inviter.id,
        organization_id: organization.id
      }
    }
  end

  def decode(token) do
    TokenHash.decode(token)
  end

  def hash(token) do
    TokenHash.hash(token)
  end
end
