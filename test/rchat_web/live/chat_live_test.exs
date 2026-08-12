defmodule RChatWeb.ChatLiveTest do
  use RChatWeb.ConnCase

  import Phoenix.LiveViewTest
  import RChat.AccountsFixtures
  import RChat.CommunitiesFixtures

  alias RChat.Communities

  describe "authentication" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/")

      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/users/log-in"
    end
  end

  describe "home" do
    setup :register_and_log_in_user

    test "shows the welcome state without communities", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "Welcome to RChat"
      assert html =~ "Create your first community"
    end

    test "redirects to the first community", %{conn: conn, scope: scope} do
      community = community_fixture(scope)

      assert {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/")
      assert path == ~p"/c/#{community.slug}"
    end

    test "creates a community with its general channel", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/communities/new")

      lv
      |> form("#community_form", community: %{name: "My Guild"})
      |> render_submit()

      assert_patch(lv, ~p"/c/my-guild")

      html = render(lv)
      assert html =~ "My Guild"
      assert html =~ "general"
    end

    test "renders errors on invalid community name", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/communities/new")

      result =
        lv
        |> form("#community_form", community: %{name: "x"})
        |> render_submit()

      assert result =~ "should be at least 2 character(s)"
    end
  end

  describe "community view" do
    setup :register_and_log_in_user

    setup %{scope: scope} do
      %{community: community_fixture(scope, %{name: "My Guild"})}
    end

    test "shows channels, members and the composer", %{conn: conn, community: community} do
      {:ok, _lv, html} = live(conn, ~p"/c/#{community.slug}")

      assert html =~ "My Guild"
      assert html =~ "general"
      assert html =~ "Members (1)"
      assert html =~ "Message #general"
    end

    test "returns 404 for non members", %{conn: conn} do
      other = community_fixture(user_scope_fixture(), %{name: "Private"})

      assert_error_sent 404, fn -> live(conn, ~p"/c/#{other.slug}") end
    end

    test "returns 404 for a channel of another community", %{conn: conn, community: community} do
      other_scope = user_scope_fixture()
      other = community_fixture(other_scope, %{name: "Private"})
      [other_channel] = Communities.list_channels(other)

      assert_error_sent 404, fn -> live(conn, ~p"/c/#{community.slug}/#{other_channel.id}") end
    end

    test "the owner can create a channel", %{conn: conn, community: community} do
      {:ok, lv, _html} = live(conn, ~p"/c/#{community.slug}/channels/new")

      lv
      |> form("#channel_form", channel: %{name: "random"})
      |> render_submit()

      assert [_general, channel] = Communities.list_channels(community)
      assert_patch(lv, ~p"/c/#{community.slug}/#{channel.id}")
      assert render(lv) =~ "random"
    end

    test "shows the current user as online", %{conn: conn, community: community} do
      {:ok, _lv, html} = live(conn, ~p"/c/#{community.slug}")

      assert html =~ "bg-success"
    end

    test "shows the empty channel state", %{conn: conn, community: community} do
      {:ok, _lv, html} = live(conn, ~p"/c/#{community.slug}")

      assert html =~ "This is the beginning of"
    end

    test "sends a message", %{conn: conn, community: community} do
      {:ok, lv, _html} = live(conn, ~p"/c/#{community.slug}")

      lv
      |> form("#composer", %{"content" => "hello from the owner"})
      |> render_submit()

      assert render(lv) =~ "hello from the owner"
      assert [message] = RChat.Chat.list_messages(hd(Communities.list_channels(community)))
      assert message.content == "hello from the owner"
    end

    test "shows a day separator before the first message", %{conn: conn, community: community} do
      {:ok, lv, _html} = live(conn, ~p"/c/#{community.slug}")

      lv
      |> form("#composer", %{"content" => "first of the day"})
      |> render_submit()

      assert render(lv) =~ Calendar.strftime(Date.utc_today(), "%d/%m/%Y")
    end

    test "receives messages from other members in realtime", %{conn: conn, community: community} do
      member = user_fixture()
      join_community(member, community)
      member_scope = RChat.Accounts.Scope.for_user(member)
      [channel] = Communities.list_channels(community)

      {:ok, lv, _html} = live(conn, ~p"/c/#{community.slug}")

      RChat.ChatFixtures.message_fixture(member_scope, community, channel, %{
        content: "hi from elsewhere"
      })

      html = render(lv)
      assert html =~ "hi from elsewhere"
      assert html =~ member.username
    end

    test "does not render messages from other channels", %{conn: conn, community: community} do
      other_scope = user_scope_fixture()
      other = community_fixture(other_scope, %{name: "Elsewhere"})
      [other_channel] = Communities.list_channels(other)

      {:ok, lv, _html} = live(conn, ~p"/c/#{community.slug}")

      RChat.ChatFixtures.message_fixture(other_scope, other, other_channel, %{
        content: "private stuff"
      })

      refute render(lv) =~ "private stuff"
    end

    test "plain members do not get the channel creation action", %{community: community} do
      member = user_fixture()
      join_community(member, community)
      conn = log_in_user(build_conn(), member)

      {:ok, _lv, html} = live(conn, ~p"/c/#{community.slug}")
      refute html =~ "New channel"

      assert {:error, {:live_redirect, %{to: path, flash: flash}}} =
               live(conn, ~p"/c/#{community.slug}/channels/new")

      assert path == ~p"/c/#{community.slug}"
      assert %{"error" => "You are not allowed to manage channels."} = flash
    end
  end
end
