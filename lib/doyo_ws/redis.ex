defmodule DoyoWs.Redis do
  @moduledoc """
  Behaviour for Redis operations
  """

  @callback get(key :: String.t()) ::
    {:ok, String.t() | nil} | {:error, term()}

  @callback hvals(key :: String.t()) ::
    {:ok, String.t() | nil} | {:error, term()}

  @callback subscribe(channel :: String.t()) ::
    {:ok, reference()} | {:error, term()}

end
