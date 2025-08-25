defmodule DoyoWs.Redis.RedisImpl do
  @behaviour DoyoWs.Redis

  def subscribe(channel) do
    Redix.PubSub.subscribe(:redix_pubsub, channel, self())
  end

  def get(key) do
    Redix.command(:redix, ["GET", key])
  end
end
