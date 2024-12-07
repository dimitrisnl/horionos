defmodule Horionos.Organizations.Schemas.Organization do
  @moduledoc """
  Organization schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Horionos.Memberships.Schemas.Membership
  alias Horionos.Organizations.Helpers.SlugGenerator

  @type t :: %__MODULE__{
          id: pos_integer(),
          title: String.t(),
          slug: String.t(),
          memberships: [Membership.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "organizations" do
    field :title, :string
    field :slug, :string

    has_many :memberships, Membership
    has_many :users, through: [:memberships, :user]

    timestamps(type: :utc_datetime)
  end

  @spec validate_title(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_title(changeset) do
    changeset
    |> validate_required([:title])
    |> validate_length(:title, min: 2, max: 255)
  end

  @spec create_changeset(map()) :: Ecto.Changeset.t()
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:title])
    |> validate_title()
    |> generate_unique_slug()
  end

  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(organization, attrs) do
    organization
    |> cast(attrs, [:title])
    |> validate_title()
  end

  @spec generate_unique_slug(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp generate_unique_slug(changeset) do
    case get_change(changeset, :title) do
      nil -> changeset
      title -> SlugGenerator.generate_unique_slug(__MODULE__, title, changeset)
    end
  end
end
