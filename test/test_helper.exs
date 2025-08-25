Mox.defmock(DoyoWs.Redis.RedisMock, for: DoyoWs.Redis)
Application.put_env(:doyo_ws, :redis_impl, DoyoWs.Redis.RedisMock)
ExUnit.start()
