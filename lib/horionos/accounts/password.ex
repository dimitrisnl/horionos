defmodule Horionos.Accounts.Password do
  @moduledoc """
  Handles password hashing, verification, and related security operations.

  This module provides a secure interface for working with passwords in the Horionos application.
  It uses Bcrypt for password hashing, which is a strong, adaptive hash function designed to resist
  various types of attacks, including rainbow table and brute-force attacks.

  Key features and responsibilities:
  - Securely hashing passwords for storage
  - Verifying passwords against their hashed versions
  - Protecting against timing attacks
  - Updating Ecto changesets with hashed passwords

  This module should be used for all password-related operations to ensure consistent
  and secure handling of passwords throughout the application.

  Note: This module does not store any passwords. It only provides functions to work
  with passwords in a secure manner.
  """

  @doc """
  Hashes a password using Bcrypt.
  """
  @spec hash(String.t()) :: String.t()
  #
  def hash(password) do
    Bcrypt.hash_pwd_salt(password)
  end

  @doc """
  Verifies a password against a hashed password.
  """
  @spec verify(String.t(), String.t()) :: boolean()
  #
  def verify(password, hashed_password) do
    Bcrypt.verify_pass(password, hashed_password)
  end

  @doc """
  Performs a dummy check to prevent timing attacks.
  """
  @spec perform_dummy_check() :: boolean()
  #
  def perform_dummy_check do
    Bcrypt.no_user_verify()
  end

  @doc """
  Hashes a password and returns an updated changeset.
  """
  @spec hash_password_changeset(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  #
  def hash_password_changeset(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        Ecto.Changeset.put_change(changeset, :hashed_password, hash(password))

      _ ->
        changeset
    end
  end
end
