defmodule Horionos.Workers.LockUnverifiedAccountsWorker do
  @moduledoc """
  Worker to lock unverified accounts that have expired.
  """
  use Oban.Worker, queue: :unverified_accounts

  alias Horionos.Accounts.Users
  alias Horionos.SystemAdmin.Notifier, as: SystemAdminNotifications

  @impl Oban.Worker
  def perform(_job) do
    SystemAdminNotifications.notify(:cron_job_started, %{
      job: %{name: "Lock unverified accounts"}
    })

    {locked_count, locked_users} = Users.lock_expired_unverified_accounts()

    for user <- locked_users do
      SystemAdminNotifications.notify(:user_locked, user)
    end

    SystemAdminNotifications.notify(:cron_job_succeeded, %{
      job: %{name: "Lock unverified accounts", details: "Locked #{locked_count} accounts"}
    })

    {:ok, locked_count}
  end
end
