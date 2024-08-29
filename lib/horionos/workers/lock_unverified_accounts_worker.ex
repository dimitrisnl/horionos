defmodule Horionos.Workers.LockUnverifiedAccountsWorker do
  @moduledoc """
  Worker to lock unverified accounts that have expired.
  """
  use Oban.Worker, queue: :unverified_accounts

  alias Horionos.Accounts
  alias Horionos.AdminNotifications

  @impl Oban.Worker
  def perform(_job) do
    AdminNotifications.notify(:cron_job_started, %{job: %{name: "Lock unverified accounts"}})
    {locked_count, locked_users} = Accounts.lock_expired_unverified_accounts()

    for user <- locked_users do
      AdminNotifications.notify(:user_locked, user)
    end

    AdminNotifications.notify(:cron_job_succeeded, %{
      job: %{name: "Lock unverified accounts", details: "Locked #{locked_count} accounts"}
    })

    {:ok, locked_count}
  end
end
