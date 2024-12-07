defmodule Horionos.MembershipsFixtures do
  @moduledoc """
  Fixtures for memberships.
  """
  alias Horionos.Memberships.Memberships

  require Logger

  def membership_fixture(attrs \\ %{}) do
    case Memberships.create_membership(attrs) do
      {:ok, membership} ->
        membership

      {:error, %Ecto.Changeset{} = changeset} ->
        raise "Failed to create membership: #{inspect(changeset.errors)}"
    end
  end
end
