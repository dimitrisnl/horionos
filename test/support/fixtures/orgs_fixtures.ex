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

    {:ok, org} = Orgs.create_org(user, attrs)
    org
  end

  def membership_fixture(creator, attrs \\ %{}) do
    case Orgs.create_membership(creator, attrs) do
      {:ok, membership} -> membership
      {:error, reason} -> raise "Failed to create membership: #{inspect(reason)}"
    end
  end
end
