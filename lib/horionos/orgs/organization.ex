defmodule Horionos.Organizations.Organization do
  @moduledoc """
  Schema and functions for managing organizations in Horionos.
  An organization can have multiple members through memberships.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Horionos.Accounts.User
  alias Horionos.Organizations.Membership
  alias Horionos.Repo

  @type t :: %__MODULE__{
          id: integer() | nil,
          title: String.t() | nil,
          slug: String.t() | nil,
          memberships: [Membership.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "organizations" do
    field :title, :string
    field :slug, :string

    has_many :memberships, Membership
    has_many :users, through: [:memberships, :user]

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for an organization.

  ## Parameters

    - organization: The organization struct to change
    - attrs: The attributes to apply to the organization

  ## Returns

    A changeset.
  """
  @spec changeset(t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:title])
    |> validate_required([:title])
    |> validate_length(:title, min: 2, max: 255)
    |> maybe_generate_unique_slug()
    |> unique_constraint(:slug)
  end

  @doc """
  Creates a changeset for adding a user to an organization.

  ## Parameters

    - organization: The organization struct
    - user: The user struct to add
    - role: The role of the user in the organization (default: :member)

  ## Returns

    A changeset.
  """
  @spec add_user_changeset(t(), User.t(), atom()) :: Ecto.Changeset.t()
  #
  def add_user_changeset(organization, user, role) do
    organization
    |> change()
    |> put_assoc(:memberships, [%Membership{user_id: user.id, role: role}])
  end

  @spec add_user_changeset(t(), User.t()) :: Ecto.Changeset.t()
  #
  def add_user_changeset(organization, user) do
    add_user_changeset(organization, user, :member)
  end

  # Private functions

  defp maybe_generate_unique_slug(changeset) do
    case get_change(changeset, :title) do
      nil -> changeset
      title -> generate_unique_slug(changeset, title)
    end
  end

  defp generate_unique_slug(changeset, title) do
    base_slug =
      title
      |> String.downcase()
      |> String.replace(~r/[^\w-]+/, "-")

    case find_unique_slug(base_slug) do
      {:ok, slug} -> put_change(changeset, :slug, slug)
      {:error, _reason} -> add_error(changeset, :title, "Unable to generate a unique slug")
    end
  end

  defp find_unique_slug(base_slug, attempt \\ 0) do
    slug = if attempt == 0, do: base_slug, else: "#{base_slug}-#{attempt}"

    case Repo.get_by(__MODULE__, slug: slug) do
      nil ->
        {:ok, slug}

      _organization ->
        if attempt < 100 do
          find_unique_slug(base_slug, attempt + 1)
        else
          {:error, :max_attempts_reached}
        end
    end
  end
end
