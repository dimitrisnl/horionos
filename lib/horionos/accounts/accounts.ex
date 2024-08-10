defmodule Horionos.Accounts do
  @moduledoc """
  The Accounts context serves as the main interface for all account-related operations.

  This module delegates to specialized sub-modules for specific functionalities:
  - UserManagement: For user creation, profile updates, and account status operations.
  - UserAuthentication: For authentication, password management, and session handling.
  - UserEmailManagement: For email-related operations such as verification and updates.

  By using this context, other parts of the application can perform account-related
  actions without needing to know the underlying implementation details.
  """

  alias Horionos.Accounts.{UserAuthentication, UserEmailManagement, UserManagement}

  # User retrieval functions
  defdelegate get_user_by_id!(id), to: UserManagement
  defdelegate get_user_by_email(email), to: UserManagement
  defdelegate get_user_by_email_and_password(email, password), to: UserAuthentication

  # User registration and profile management
  defdelegate register_user(attrs), to: UserManagement
  defdelegate build_registration_changeset(user, attrs \\ %{}), to: UserManagement
  defdelegate build_full_name_changeset(user, attrs \\ %{}), to: UserManagement
  defdelegate update_user_full_name(user, attrs), to: UserManagement

  # Email management
  defdelegate build_email_changeset(user, attrs \\ %{}), to: UserEmailManagement
  defdelegate apply_email_change(user, password, attrs), to: UserEmailManagement
  defdelegate update_user_email(user, token), to: UserEmailManagement

  defdelegate send_update_email_instructions(user, current_email, update_email_url_fun),
    to: UserEmailManagement

  defdelegate send_confirmation_instructions(user, confirmation_url_fun),
    to: UserEmailManagement

  defdelegate confirm_user_email(token), to: UserEmailManagement
  defdelegate email_verified?(user), to: UserEmailManagement
  defdelegate get_email_verification_deadline(user), to: UserEmailManagement
  defdelegate email_verification_pending?(user), to: UserEmailManagement
  defdelegate email_verified_or_pending?(user), to: UserEmailManagement

  # Authentication and password management
  defdelegate build_password_changeset(user, attrs \\ %{}), to: UserAuthentication
  defdelegate update_user_password(user, password, attrs), to: UserAuthentication
  defdelegate create_session_token(user, device_info \\ nil), to: UserAuthentication
  defdelegate get_user_from_session_token(token), to: UserAuthentication
  defdelegate revoke_session_token(token), to: UserAuthentication
  defdelegate list_user_sessions(user, current_token), to: UserAuthentication
  defdelegate revoke_other_user_sessions(user, current_token), to: UserAuthentication

  defdelegate send_reset_password_instructions(user, reset_password_url_fun),
    to: UserAuthentication

  defdelegate get_user_from_reset_token(token), to: UserAuthentication
  defdelegate reset_user_password(user, attrs), to: UserAuthentication

  # User status checks and locking operations
  defdelegate user_locked?(user), to: UserManagement
  defdelegate lock_user(user), to: UserManagement
  defdelegate unlock_user(user), to: UserManagement
  defdelegate lock_expired_unverified_accounts(), to: UserManagement
end
