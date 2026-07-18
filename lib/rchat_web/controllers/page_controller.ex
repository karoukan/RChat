defmodule RChatWeb.PageController do
  use RChatWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
