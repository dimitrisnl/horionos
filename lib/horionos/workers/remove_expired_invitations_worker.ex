defmodule Horionos.Workers.DeleteExpiredInvitationsWorker do
  @moduledoc """
  Worker to remove expired invitations.
  """
  use Oban.Worker, queue: :expired_invitations

  alias Horionos.Invitations.Invitations
  alias Horionos.SystemAdmin.Notifier, as: SystemAdminNotifications

  @impl Oban.Worker
  def perform(_job) do
    SystemAdminNotifications.notify(:cron_job_started, %{
      job: %{name: "Delete expired invitations"}
    })

    {deleted_count, _} = Invitations.delete_expired_invitations()

    SystemAdminNotifications.notify(:cron_job_succeeded, %{
      job: %{name: "Delete expired invitations", details: "Deleted #{deleted_count} invitations"}
    })

    {:ok, deleted_count}
  end
end
