defmodule RChatWeb.JoinLiveTest do
  use RChatWeb.ConnCase

  import Phoenix.LiveViewTest
  import RChat.AccountsFixtures
  import RChat.CommunitiesFixtures

  alias RChat.Communities

  setup do
    owner_scope = user_scope_fixture()
    community = community_fixture(owner_scope, %{name: "My Guild"})
    {:ok, invite} = Communities.create_invite(owner_scope, community)

    %{community: community, invite: invite}
  end

  test "shows the community to anonymous visitors", %{
    conn: conn,
    invite: invite,
    community: community
  } do
    {:ok, _lv, html} = live(conn, ~p"/join/#{invite.code}")

    assert html =~ community.name
    assert html =~ "Create an account"
    assert html =~ "I already have an account"
  end

  test "shows an error for invalid codes", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/join/nope")

    assert html =~ "Invalid invite"
  end

  test "lets a logged in user join", %{conn: conn, invite: invite, community: community} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, lv, html} = live(conn, ~p"/join/#{invite.code}")
    assert html =~ "Join My Guild"

    lv |> element("button", "Join My Guild") |> render_click()

    flash = assert_redirect(lv, ~p"/c/#{community.slug}")
    assert flash["info"] =~ "Welcome to My Guild"

    scope = RChat.Accounts.Scope.for_user(user)
    assert Communities.get_membership(scope, community)
  end

  test "redirects members straight to the community", %{
    conn: conn,
    invite: invite,
    community: community
  } do
    user = user_fixture()
    join_community(user, community)
    conn = log_in_user(conn, user)

    {:ok, lv, _html} = live(conn, ~p"/join/#{invite.code}")
    lv |> element("button", "Join My Guild") |> render_click()

    assert_redirect(lv, ~p"/c/#{community.slug}")
  end
end
