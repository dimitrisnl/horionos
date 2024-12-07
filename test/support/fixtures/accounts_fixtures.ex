defmodule Horionos.AccountsFixtures do
  @moduledoc """
  Fixtures for accounts.
  """
  alias Horionos.Accounts.Schemas.User
  alias Horionos.Repo

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"
  def valid_user_full_name, do: "John Doe #{System.unique_integer()}"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password(),
      full_name: valid_user_full_name()
    })
  end

  def user_fixture(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(valid_user_attributes(attrs))
    |> Ecto.Changeset.put_change(
      :confirmed_at,
      NaiveDateTime.utc_now(:second)
    )
    |> Repo.insert!()
  end

  def unconfirmed_user_fixture(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(valid_user_attributes(attrs))
    |> Repo.insert!()
  end
end
