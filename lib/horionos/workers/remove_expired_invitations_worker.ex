defmodule Horionos.Workers.DeleteExpiredInvitationsWorker do
  @moduledoc """
  Worker to remove expired invitations.
  """
  use Oban.Worker, queue: :expired_invitations

  alias Horionos.AdminNotifications
  alias Horionos.Organizations

  @impl Oban.Worker
  def perform(_job) do
    AdminNotifications.notify(:cron_job_started, %{job: %{name: "Delete expired invitations"}})
    {deleted_count, _} = Organizations.delete_expired_invitations()

    AdminNotifications.notify(:cron_job_succeeded, %{
      job: %{name: "Delete expired invitations", details: "Deleted #{deleted_count} invitations"}
    })

    {:ok, deleted_count}
  end
end
