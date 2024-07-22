defmodule Horionos.Orgs.MembershipRole do
  @moduledoc """
  Defines and manages roles for organization memberships in Horionos.
  """

  @typedoc "Valid membership roles"
  @type t :: :owner | :admin | :member

  @roles [:owner, :admin, :member]

  @doc "List of all valid roles"
  @spec all :: [t()]
  #
  def all, do: @roles

  @doc "Checks if the given role is :owner"
  @spec owner?(t()) :: boolean()
  #
  def owner?(role), do: role == :owner

  @doc "Checks if the given role is :admin"
  @spec admin?(t()) :: boolean()
  #
  def admin?(role), do: role == :admin

  @doc "Checks if the given role is :member"
  @spec member?(t()) :: boolean()
  #
  def member?(role), do: role == :member

  @doc "Validates if the given role is a valid membership role"
  @spec valid?(any()) :: boolean()
  #
  def valid?(role) when role in @roles, do: true
  def valid?(_), do: false

  @doc "Converts a string to a role atom if valid, otherwise returns an error"
  @spec cast(String.t()) :: {:ok, t()} | :error
  #
  def cast(role) when is_binary(role) do
    case String.to_existing_atom(role) do
      role when role in @roles -> {:ok, role}
      _ -> :error
    end
  rescue
    ArgumentError -> :error
  end

  def cast(_), do: :error

  @doc "Returns the highest role from a list of roles"
  @spec highest([t()]) :: t() | nil
  #
  def highest(roles) do
    Enum.find(all(), &(&1 in roles))
  end

  @doc "Checks if the first role is higher or equal to the second role"
  @spec at_least?(t(), t()) :: boolean()
  #
  def at_least?(role1, role2) do
    index1 = Enum.find_index(all(), &(&1 == role1))
    index2 = Enum.find_index(all(), &(&1 == role2))
    index1 <= index2
  end
end
