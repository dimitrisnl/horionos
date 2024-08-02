ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Horionos.Repo, :manual)
Mox.defmock(Horionos.Services.RateLimiterMock, for: Horionos.Services.RateLimiter)
