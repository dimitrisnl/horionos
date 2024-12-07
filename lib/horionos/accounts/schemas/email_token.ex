defmodule Horionos.Accounts.Schemas.EmailToken do
  @moduledoc """
  Email token schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Horionos.Accounts.Schemas.User
  alias Horionos.Services.TokenHash

  @type t :: %__MODULE__{
          id: pos_integer(),
          token: binary(),
          context: String.t(),
          sent_to: String.t(),
          user: User.t() | Ecto.Association.NotLoaded.t(),
          user_id: pos_integer(),
          inserted_at: DateTime.t()
        }

  schema "email_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    belongs_to :user, User

    timestamps(updated_at: false)
  end

  # Todo: validate the context
  def create_email_token(user, context) do
    {token, attrs} = build_hashed_token(user, context, user.email)

    changeset =
      %__MODULE__{}
      |> cast(attrs, [:token, :context, :sent_to, :user_id])
      |> foreign_key_constraint(:user_id)

    {token, changeset}
  end

  @spec build_hashed_token(User.t(), String.t(), String.t()) :: {binary(), map()}
  defp build_hashed_token(user, context, sent_to) do
    token = TokenHash.generate_token()

    encoded_token = TokenHash.encode(token)
    hashed_token = TokenHash.hash(token)

    {encoded_token,
     %{
       token: hashed_token,
       context: context,
       sent_to: sent_to,
       user_id: user.id
     }}
  end

  def decode(token) do
    TokenHash.decode(token)
  end

  def hash(token) do
    TokenHash.hash(token)
  end
end
