defmodule RChat.CommunitiesFixtures do
  @moduledoc """
  Test helpers for creating entities via the `RChat.Communities` context.
  """

  alias RChat.Communities
  alias RChat.Communities.Membership

  def unique_community_name, do: "community #{System.unique_integer([:positive])}"

  def community_fixture(scope, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: unique_community_name()})

    {:ok, community} = Communities.create_community(scope, attrs)
    community
  end

  def join_community(user, community) do
    RChat.Repo.insert!(%Membership{user_id: user.id, community_id: community.id})
  end
end
