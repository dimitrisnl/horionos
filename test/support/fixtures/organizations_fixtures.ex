defmodule Horionos.OrganizationsFixtures do
  @moduledoc """
  Fixtures for organizations.
  """
  alias Horionos.AccountsFixtures
  alias Horionos.Organizations.Organizations

  require Logger

  def organization_fixture(attrs \\ %{})

  def organization_fixture(%{user: user} = attrs) do
    attrs = Map.delete(attrs, :user)
    do_organization_fixture(user, attrs)
  end

  def organization_fixture(attrs) do
    do_organization_fixture(AccountsFixtures.user_fixture(), attrs)
  end

  defp do_organization_fixture(user, attrs) do
    attrs =
      Enum.into(attrs, %{
        title: "Organization #{System.unique_integer([:positive])}"
      })

    case Organizations.create_organization(user, attrs) do
      {:ok, organization} -> organization
      {:error, reason} -> raise "Failed to create organization: #{inspect(reason)}"
    end
  end
end
