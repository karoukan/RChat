defmodule RChatWeb.UserLive.RegistrationTest do
  use RChatWeb.ConnCase

  import Phoenix.LiveViewTest
  import RChat.AccountsFixtures

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Create an account"
      assert html =~ "Log in"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces", "password" => "short"})

      assert result =~ "Create an account"
      assert result =~ "must have the @ sign and no spaces"
      assert result =~ "should be at least 12 character(s)"
    end
  end

  describe "register user" do
    test "creates account and triggers the log in form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      attrs = valid_user_attributes()
      form = form(lv, "#registration_form", user: attrs)
      render_submit(form)

      conn = follow_trigger_action(form, conn)
      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_token)

      assert RChat.Accounts.get_user_by_email(attrs.email)
    end

    test "renders errors for duplicated email", %{conn: conn} do
      %{user: user, invite: invite} = existing_user_with_invite()

      {:ok, lv, _html} = live(conn, ~p"/users/register?invite=#{invite.code}")

      result =
        lv
        |> form("#registration_form",
          user: valid_user_attributes(email: user.email)
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end

    test "renders errors for duplicated username", %{conn: conn} do
      %{user: user, invite: invite} = existing_user_with_invite()

      {:ok, lv, _html} = live(conn, ~p"/users/register?invite=#{invite.code}")

      result =
        lv
        |> form("#registration_form",
          user: valid_user_attributes(username: user.username)
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end

  describe "invite gating" do
    test "the first account can register without an invite", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "first account of this server"
      assert html =~ "registration_form"
    end

    test "registration is closed without an invite once users exist", %{conn: conn} do
      user_fixture()

      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Invite only"
      refute html =~ "registration_form"
    end

    test "registration is closed with an invalid invite code", %{conn: conn} do
      user_fixture()

      {:ok, _lv, html} = live(conn, ~p"/users/register?invite=nope")

      assert html =~ "Invite only"
    end

    test "a valid invite opens registration and joins the community", %{conn: conn} do
      %{invite: invite, community: community} = existing_user_with_invite()

      {:ok, lv, html} = live(conn, ~p"/users/register?invite=#{invite.code}")
      assert html =~ community.name

      attrs = valid_user_attributes()

      lv
      |> form("#registration_form", user: attrs)
      |> render_submit()

      user = RChat.Accounts.get_user_by_email(attrs.email)
      scope = RChat.Accounts.Scope.for_user(user)
      assert RChat.Communities.get_membership(scope, community)
    end
  end

  defp existing_user_with_invite do
    scope = user_scope_fixture()
    community = RChat.CommunitiesFixtures.community_fixture(scope)
    {:ok, invite} = RChat.Communities.create_invite(scope, community)

    %{user: scope.user, community: community, invite: invite}
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Log in")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert login_html =~ "Log in"
    end
  end
end
