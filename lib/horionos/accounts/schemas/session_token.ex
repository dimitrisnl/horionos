defmodule Horionos.Accounts.Schemas.SessionToken do
  @moduledoc """
  Session token schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Horionos.Accounts.Schemas.User
  alias Horionos.Constants
  alias Horionos.Services.TokenHash

  @session_validity_in_days Constants.session_validity_in_days()

  @type t :: %__MODULE__{
          id: pos_integer(),
          token: binary(),
          user: User.t() | Ecto.Association.NotLoaded.t(),
          user_id: pos_integer(),
          device: String.t(),
          os: String.t(),
          browser: String.t(),
          browser_version: String.t(),
          inserted_at: NaiveDateTime.t()
        }

  schema "session_tokens" do
    field :token, :binary
    field :device, :string
    field :os, :string
    field :browser, :string
    field :browser_version

    belongs_to :user, User

    timestamps(updated_at: false)
  end

  def days_for_session_validity, do: @session_validity_in_days

  @spec create_session(User.t(), map() | nil) :: {binary(), Ecto.Changeset.t()}
  def create_session(user, device_info \\ %{}) do
    device_info = device_info || %{}

    token = TokenHash.generate_token()

    attrs =
      %{
        token: token,
        user_id: user.id,
        device: Map.get(device_info, :device, "Unknown"),
        os: Map.get(device_info, :os, "Unknown"),
        browser: Map.get(device_info, :browser, "Unknown"),
        browser_version: Map.get(device_info, :browser_version, "")
      }

    changeset =
      %__MODULE__{}
      |> cast(attrs, [:token, :user_id, :device, :os, :browser, :browser_version])
      |> validate_required([:token, :user_id])
      |> foreign_key_constraint(:user_id)

    {token, changeset}
  end
end
