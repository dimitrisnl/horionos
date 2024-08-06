defmodule Horionos.Workers.LockUnverifiedAccountsWorker do
  @moduledoc """
  Worker to lock unverified accounts that have expired.
  """
  use Oban.Worker, queue: :unverified_accounts

  alias Horionos.Accounts
  alias Horionos.Notifications

  @impl Oban.Worker
  def perform(_job) do
    {locked_count, locked_users} = Accounts.lock_expired_unverified_accounts()

    for user <- locked_users do
      Notifications.notify(:user_locked, user)
    end

    {:ok, locked_count}
  end
end
