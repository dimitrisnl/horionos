defmodule Horionos.Accounts.Password do
  def hash(password) do
    Bcrypt.hash_pwd_salt(password)
  end

  def verify(password, hashed_password) do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def hash_and_stub_false do
    Bcrypt.no_user_verify()
  end
end
