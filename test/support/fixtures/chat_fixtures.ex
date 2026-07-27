defmodule RChat.ChatFixtures do
  @moduledoc """
  Test helpers for creating entities via the `RChat.Chat` context.
  """

  alias RChat.Chat

  def message_fixture(scope, community, channel, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{content: "some message #{System.unique_integer([:positive])}"})

    {:ok, message} = Chat.create_message(scope, community, channel, attrs)
    message
  end
end
