defmodule Horionos.Accounts.Notifications.Dispatcher do
  @moduledoc """
  Unified notification dispatcher supporting multiple channels
  """
  alias Horionos.Accounts.Notifications.Channels.Email

  @spec notify(key :: atom(), metadata :: map()) ::
          {:ok, map()} | {:error, term()}
  def notify(key, metadata) do
    channels = resolve_channels(key)

    Enum.reduce_while(channels, {:ok, %{}}, fn channel, {:ok, results} ->
      case channel.deliver(key, metadata) do
        {:ok, result} ->
          {:cont, {:ok, Map.put(results, channel, result)}}

        {:error, reason} ->
          {:halt, {:error, %{channel: channel, reason: reason}}}
      end
    end)
  end

  @spec resolve_channels(atom()) :: [Email]
  def resolve_channels(:reset_password_instructions), do: [Email]
  def resolve_channels(:confirm_email_instructions), do: [Email]
  def resolve_channels(:update_email_instructions), do: [Email]
  def resolve_channels(:new_invitation), do: [Email]
  def resolve_channels(_), do: [Email]
end
