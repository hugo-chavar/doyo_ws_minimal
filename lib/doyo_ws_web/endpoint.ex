defmodule DoyoWsWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :doyo_ws

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_doyo_ws_key",
    signing_salt: "uDMujvQN",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]


  # Temporary debug version - add this to your endpoint.ex
  allowed_origins = System.get_env("ALLOWED_WEBSOCKET_ORIGINS", "http://localhost:3000")
                  |> String.split(",")
                  |> Enum.map(&String.trim/1)

  # Add this line to see what's actually being loaded
  IO.inspect("Allowed WebSocket origins: #{inspect(allowed_origins)}")

  socket "/new_ws", DoyoWsWeb.UserSocket,
    # to remove /websocket see https://chatgpt.com/share/67e1d7d9-49e4-8000-b3f1-0e1f2fadf226 nginx solution
    websocket: [
      timeout: 600_000, # 10 minutes
      check_origin: allowed_origins
    ],
    longpoll: false

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :doyo_ws,
    gzip: false,
    only: DoyoWsWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug DoyoWsWeb.Router
end
