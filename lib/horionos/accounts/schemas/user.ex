defmodule Horionos.Accounts.Schemas.User do
  @moduledoc """
  Defines the User schema and provides changeset functions for user-related operations.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Horionos.Accounts.Helpers.Password
  alias Horionos.Accounts.Schemas.User
  alias Horionos.Memberships.Schemas.Membership

  # Prevent password leaks in logs
  @derive {Inspect, except: [:password, :hashed_password]}

  schema "users" do
    field :full_name, :string
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :naive_datetime
    field :locked_at, :utc_datetime

    has_many :memberships, Membership

    timestamps(type: :utc_datetime)
  end

  @type empty :: %__MODULE__{}
  @type t :: %__MODULE__{
          id: pos_integer(),
          full_name: String.t(),
          email: String.t(),
          hashed_password: String.t(),
          inserted_at: DateTime.t(),
          memberships: [Membership.t()] | Ecto.Association.NotLoaded.t(),
          password: String.t(),
          confirmed_at: NaiveDateTime.t() | nil,
          locked_at: DateTime.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @type validate_options :: [validate_email: boolean(), hash_password: boolean()]
  @spec registration_changeset(empty() | t(), map(), validate_options()) :: Ecto.Changeset.t()
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:full_name, :email, :password])
    |> validate_full_name()
    |> validate_email(opts)
    |> validate_password(opts)
  end

  @spec full_name_changeset(t, map()) :: Ecto.Changeset.t()
  def full_name_changeset(user, attrs) do
    user
    |> cast(attrs, [:full_name])
    |> validate_full_name()
  end

  @spec email_changeset(t, map(), Keyword.t()) :: Ecto.Changeset.t()
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @spec password_changeset(t, map(), Keyword.t()) :: Ecto.Changeset.t()
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_password(opts)
  end

  @spec confirm_changeset(t() | Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def confirm_changeset(user_or_changeset) do
    now = NaiveDateTime.utc_now(:second)
    change(user_or_changeset, confirmed_at: now)
  end

  @spec valid_password?(t, String.t()) :: boolean()
  def valid_password?(%User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Password.verify(password, hashed_password)
  end

  def valid_password?(_, _) do
    Password.perform_dummy_check()
    false
  end

  @spec validate_current_password(Ecto.Changeset.t(), String.t()) :: Ecto.Changeset.t()
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  defp validate_full_name(changeset) do
    changeset
    |> validate_required([:full_name])
    |> validate_length(:full_name, min: 2)
    |> validate_length(:full_name, max: 160)
  end

  @spec validate_email(Ecto.Changeset.t(), Keyword.t()) :: Ecto.Changeset.t()
  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  @spec validate_password(Ecto.Changeset.t(), Keyword.t()) :: Ecto.Changeset.t()
  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  @spec maybe_hash_password(Ecto.Changeset.t(), Keyword.t()) :: Ecto.Changeset.t()
  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> validate_length(:password, max: 72, count: :bytes)
      |> Password.hash_password_changeset()
      |> delete_change(:password)
    else
      changeset
    end
  end

  @spec maybe_validate_unique_email(Ecto.Changeset.t(), Keyword.t()) :: Ecto.Changeset.t()
  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Horionos.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end
end
