defmodule RChatWeb.Presence do
  use Phoenix.Presence,
    otp_app: :rchat,
    pubsub_server: RChat.PubSub
end
