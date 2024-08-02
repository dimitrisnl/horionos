defmodule Horionos.Accounts.Password do
  @moduledoc """
  Handles password hashing and verification.
  """

  @doc """
  Hashes a password using Bcrypt.

  ## Parameters

    - `password` - The password to hash.

  ## Returns

    The hashed password.
  """
  @spec hash(String.t()) :: String.t()
  #
  def hash(password) do
    Bcrypt.hash_pwd_salt(password)
  end

  @doc """
  Verifies a password against a hashed password.

  ## Parameters

    - `password` - The password to verify.
    - `hashed_password` - The hashed password to verify against.

  ## Returns

    `true` if the password is verified, `false` otherwise.
  """
  @spec verify(String.t(), String.t()) :: boolean()
  #
  def verify(password, hashed_password) do
    Bcrypt.verify_pass(password, hashed_password)
  end

  @doc """
  Performs a dummy check to prevent timing attacks.
  """
  @spec hash_and_stub_false() :: boolean()
  #
  def hash_and_stub_false do
    Bcrypt.no_user_verify()
  end

  @doc """
  Hashes a password and returns an updated changeset.

  ## Parameters

    - `changeset` - The changeset to update.

  ## Returns

    The updated changeset.
  """
  @spec hash_password(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  #
  def hash_password(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        Ecto.Changeset.put_change(changeset, :hashed_password, hash(password))

      _ ->
        changeset
    end
  end
end
