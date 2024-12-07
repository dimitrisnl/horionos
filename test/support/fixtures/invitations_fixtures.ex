defmodule Horionos.InvitationsFixtures do
  @moduledoc """
  Fixtures for invitations.
  """
  alias Horionos.Invitations.Invitations

  def invitation_fixture(inviter, organization, email, role \\ :member) do
    {:ok, invitation} = Invitations.create_invitation(inviter, organization, email, role)
    invitation
  end
end
