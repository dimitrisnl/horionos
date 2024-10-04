defmodule Horionos.Constants do
  @moduledoc """
  Provides centralized access to application configuration.
  """

  @app :horionos

  # Compile-time configurations
  @reset_password_validity_in_days Application.compile_env(@app, :reset_password_validity_in_days)
  @confirm_validity_in_days Application.compile_env(@app, :confirm_validity_in_days)
  @change_email_validity_in_days Application.compile_env(@app, :change_email_validity_in_days)
  @session_validity_in_days Application.compile_env(@app, :session_validity_in_days)
  @unconfirmed_email_deadline_in_days Application.compile_env(
                                        @app,
                                        :unconfirmed_email_deadline_in_days
                                      )
  @unconfirmed_email_lock_deadline_in_days Application.compile_env(
                                             @app,
                                             :unconfirmed_email_lock_deadline_in_days
                                           )
  @invitation_validity_in_days Application.compile_env(@app, :invitation_validity_in_days)
  @from_email Application.compile_env(@app, :from_email)
  @from_name Application.compile_env(@app, :from_name)

  def reset_password_validity_in_days, do: @reset_password_validity_in_days
  def confirm_validity_in_days, do: @confirm_validity_in_days
  def change_email_validity_in_days, do: @change_email_validity_in_days
  def session_validity_in_days, do: @session_validity_in_days
  def unconfirmed_email_deadline_in_days, do: @unconfirmed_email_deadline_in_days
  def unconfirmed_email_lock_deadline_in_days, do: @unconfirmed_email_lock_deadline_in_days
  def invitation_validity_in_days, do: @invitation_validity_in_days
  def from_email, do: @from_email
  def from_name, do: @from_name

  def hash_algorithm, do: :sha256
  def rand_size, do: 32
end
