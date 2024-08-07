defmodule Horionos.AnnouncementsFixtures do
  @moduledoc """
  Fixtures for announcements.
  """
  alias Horionos.Announcements

  def unique_announcement_title, do: "Announcement #{System.unique_integer()}"
  def unique_announcement_body, do: "Body #{System.unique_integer()}"

  def valid_announcement_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      title: unique_announcement_title(),
      body: unique_announcement_body()
    })
  end

  def announcement_fixture(user, org, attrs \\ %{}) do
    attrs = valid_announcement_attributes(attrs)
    attrs = Map.put(attrs, :org_id, org.id)

    {:ok, announcement} =
      Announcements.create_announcement(user, org.id, attrs)

    announcement
  end
end
