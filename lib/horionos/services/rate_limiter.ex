defmodule Horionos.Services.RateLimiter do
  @moduledoc """
  Rate limiter service.
  """
  use GenServer

  @callback check_rate(String.t(), integer(), integer()) :: :ok | :error
  @table_name :rate_limiter

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  #
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec init(any()) :: {:ok, map()}
  #
  def init(_) do
    :ets.new(@table_name, [:set, :named_table, :public, read_concurrency: true])
    {:ok, %{}}
  end

  @doc """
  Checks if the action is allowed based on the given key, limit, and time window.

  ## Parameters

    - key: A unique identifier for the action (e.g., "confirm_email_instructions:user@example.com")
    - limit: The maximum number of actions allowed within the time window
    - window: The time window in milliseconds

  ## Returns

    - `{:ok}` if the action is allowed
    - `{:error, :rate_limit_exceeded}` if the action is not allowed
  """
  @spec check_rate(String.t(), integer(), integer()) :: {:ok} | {:error, :rate_limit_exceeded}
  #
  def check_rate(key, limit, window) do
    now = System.system_time(:millisecond)

    case :ets.lookup(@table_name, key) do
      [{^key, _count, last_reset}] when now - last_reset > window ->
        :ets.insert(@table_name, {key, 1, now})
        {:ok}

      [{^key, count, _last_reset}] when count >= limit ->
        {:error, :rate_limit_exceeded}

      [{^key, _count, _last_reset}] ->
        :ets.update_counter(@table_name, key, {2, 1})
        {:ok}

      [] ->
        :ets.insert(@table_name, {key, 1, now})
        {:ok}
    end
  end
end
