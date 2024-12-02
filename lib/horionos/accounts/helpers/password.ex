defmodule Horionos.Accounts.Helpers.Password do
  @moduledoc """
  Handles password hashing
  """

  @spec hash(String.t()) :: String.t()
  def hash(password) do
    Bcrypt.hash_pwd_salt(password)
  end

  @spec verify(String.t(), String.t()) :: boolean()
  def verify(password, hashed_password) do
    Bcrypt.verify_pass(password, hashed_password)
  end

  @spec perform_dummy_check() :: boolean()
  def perform_dummy_check do
    Bcrypt.no_user_verify()
  end

  @spec hash_password_changeset(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def hash_password_changeset(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        Ecto.Changeset.put_change(changeset, :hashed_password, hash(password))

      _ ->
        changeset
    end
  end
end
