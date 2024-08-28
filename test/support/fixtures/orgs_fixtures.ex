defmodule Horionos.OrgsFixtures do
  @moduledoc """
  Fixtures for orgs.
  """
  alias Horionos.AccountsFixtures
  alias Horionos.Orgs

  require Logger

  def org_fixture(attrs \\ %{})

  def org_fixture(%{user: user} = attrs) do
    attrs = Map.delete(attrs, :user)
    do_org_fixture(user, attrs)
  end

  def org_fixture(attrs) do
    do_org_fixture(AccountsFixtures.user_fixture(), attrs)
  end

  defp do_org_fixture(user, attrs) do
    attrs =
      Enum.into(attrs, %{
        title: "Org #{System.unique_integer([:positive])}"
      })

    case Orgs.create_org(user, attrs) do
      {:ok, org} -> org
      {:error, reason} -> raise "Failed to create org: #{inspect(reason)}"
    end
  end

  def membership_fixture(attrs \\ %{}) do
    case Orgs.create_membership(attrs) do
      {:ok, membership} ->
        membership

      {:error, %Ecto.Changeset{} = changeset} ->
        raise "Failed to create membership: #{inspect(changeset.errors)}"
    end
  end

  def invitation_fixture(inviter, org, email, role \\ :member) do
    {:ok, invitation} = Orgs.create_invitation(inviter, org, email, role)
    invitation
  end
end
