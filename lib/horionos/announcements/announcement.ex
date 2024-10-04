defmodule Horionos.Announcements.Announcement do
  @moduledoc """
  Schema and changeset functions for Announcements.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Horionos.Organizations.Organization

  @type t :: %__MODULE__{
          id: integer() | nil,
          title: String.t(),
          body: String.t(),
          organization: Organization.t() | Ecto.Association.NotLoaded.t(),
          organization_id: integer() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "announcements" do
    field :title, :string
    field :body, :string
    belongs_to :organization, Organization

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for an announcement.
  """
  def changeset(announcement, attrs) do
    announcement
    |> cast(attrs, [:title, :body])
    |> validate_required([:title, :body])
    |> validate_length(:title, max: 255)
    |> validate_length(:body, max: 10_000)
    |> foreign_key_constraint(:organization_id)
  end
end
