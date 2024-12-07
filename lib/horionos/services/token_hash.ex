defmodule Horionos.Services.TokenHash do
  @moduledoc """
  Utility for generating and managing secure token hashes.
  """

  alias Horionos.Constants

  @hash_algorithm Constants.hash_algorithm()
  @rand_size Constants.rand_size()

  @spec generate_token() :: binary()
  def generate_token do
    :crypto.strong_rand_bytes(@rand_size)
  end

  @spec hash(binary()) :: binary()
  def hash(token) do
    :crypto.hash(@hash_algorithm, token)
  end

  @spec generate() :: {binary(), binary()}
  def generate do
    raw_token = generate_token()
    {raw_token, hash(raw_token)}
  end

  @spec encode(binary()) :: binary()
  def encode(token) do
    Base.url_encode64(token, padding: false)
  end

  @spec decode(binary()) :: {:ok, binary()} | :error
  def decode(encoded_token) do
    Base.url_decode64(encoded_token, padding: false)
  end
end
