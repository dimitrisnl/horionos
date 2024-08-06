defmodule Horionos.Accounts.User do
  @moduledoc """
  Schema and changeset functions for User accounts.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Horionos.Accounts.Password

  # Prevent password leaks in logs
  @derive {Inspect, except: [:password, :hashed_password]}

  schema "users" do
    field :full_name, :string
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :naive_datetime
    field :locked_at, :utc_datetime

    has_many :memberships, Horionos.Orgs.Membership

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          confirmed_at: NaiveDateTime.t() | nil,
          full_name: String.t() | nil,
          email: String.t() | nil,
          hashed_password: String.t() | nil,
          id: integer() | nil,
          inserted_at: DateTime.t() | nil,
          memberships: [Horionos.Orgs.Membership.t()] | Ecto.Association.NotLoaded.t(),
          password: String.t() | nil,
          updated_at: DateTime.t() | nil,
          locked_at: DateTime.t() | nil
        }

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.

    * `:validate_email` - Validates the uniqueness of the email, in case
      you don't want to validate the uniqueness of the email (like when
      using this changeset for validations on a LiveView form before
      submitting the form), this option can be set to `false`.
      Defaults to `true`.

  ## Returns

  A changeset with the validated data.
  """
  @spec registration_changeset(t(), map(), Keyword.t()) :: Ecto.Changeset.t()
  #
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:full_name, :email, :password])
    |> validate_full_name()
    |> validate_email(opts)
    |> validate_password(opts)
  end

  @doc """
  A user changeset for updating the full name.

  """
  @spec full_name_changeset(t, map()) :: Ecto.Changeset.t()
  #
  def full_name_changeset(user, attrs) do
    user
    |> cast(attrs, [:full_name])
    |> validate_full_name()
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  @spec email_changeset(t, map(), Keyword.t()) :: Ecto.Changeset.t()
  #
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  @spec password_changeset(t, map(), Keyword.t()) :: Ecto.Changeset.t()
  #
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  @spec confirm_changeset(t() | Ecto.Changeset.t()) :: Ecto.Changeset.t()
  #
  def confirm_changeset(user_or_changeset) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user_or_changeset, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  @spec valid_password?(t, String.t()) :: boolean()
  #
  def valid_password?(%Horionos.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Password.verify(password, hashed_password)
  end

  def valid_password?(_, _) do
    Password.hash_and_stub_false()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  @spec validate_current_password(Ecto.Changeset.t(), String.t()) :: Ecto.Changeset.t()
  #
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  ## Private functions

  defp validate_full_name(changeset) do
    changeset
    |> validate_required([:full_name])
    |> validate_length(:full_name, min: 2)
    |> validate_length(:full_name, max: 160)
  end

  @spec validate_email(Ecto.Changeset.t(), Keyword.t()) :: Ecto.Changeset.t()
  #
  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  @spec validate_password(Ecto.Changeset.t(), Keyword.t()) :: Ecto.Changeset.t()
  #
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
  #
  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> validate_length(:password, max: 72, count: :bytes)
      |> Password.hash_password()
      |> delete_change(:password)
    else
      changeset
    end
  end

  @spec maybe_validate_unique_email(Ecto.Changeset.t(), Keyword.t()) :: Ecto.Changeset.t()
  #
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
