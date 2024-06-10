# Should be used when fetching resources
defmodule Horionos.Repo do
  use Ecto.Repo,
    otp_app: :horionos,
    adapter: Ecto.Adapters.Postgres

  require Ecto.Query

  # @impl true
  # def prepare_query(_operation, query, opts) do
  #   cond do
  #     # skip doing org things for schema_migrations and operations specifically opting out
  #     opts[:skip_org_id] || opts[:schema_migration] ->
  #       {query, opts}

  #     # add the org_id to the query
  #     org_id = opts[:org_id] ->
  #       {Ecto.Query.where(query, org_id: ^org_id), opts}

  #     # fail compilation if we're missing org_id or skip_org_id
  #     true ->
  #       raise "expected `org_id` or `skip_org_id` to be set"
  #   end
  # end

  # @impl true
  # def default_options(_operation) do
  #   # pull org_id from the process dictionary,
  #   # and add as default option on queries
  #   [org_id: get_org_id()]
  # end

  # @org_key {__MODULE__, :org_id}

  # @doc """
  # Set the org_id on the process dictionary.  Called by plugs.
  # """
  # def put_org_id(org_id) do
  #   Process.put(@org_key, org_id)
  # end

  # @doc """
  # Get the org_id from the process dictionary.
  # """
  # def get_org_id() do
  #   Process.get(@org_key)
  # end
end
