defmodule Horionos.Announcements.Announcement do
  @moduledoc """
  Schema and changeset functions for Announcements.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Horionos.Orgs.Org

  @type t :: %__MODULE__{
          id: integer() | nil,
          title: String.t(),
          body: String.t(),
          org: Org.t() | Ecto.Association.NotLoaded.t(),
          org_id: integer() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "announcements" do
    field :title, :string
    field :body, :string
    belongs_to :org, Org

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for an announcement.
  """
  def changeset(announcement, attrs) do
    announcement
    |> cast(attrs, [:title, :body, :org_id])
    |> validate_required([:title, :body, :org_id])
    |> validate_length(:title, max: 255)
    |> validate_length(:body, max: 10000)
    |> foreign_key_constraint(:org_id)
  end
end
