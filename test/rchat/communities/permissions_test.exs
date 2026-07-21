defmodule RChat.Communities.PermissionsTest do
  use ExUnit.Case, async: true

  alias RChat.Communities.Permissions

  describe "bit/1" do
    test "every permission has a distinct single bit" do
      bits = Enum.map(Permissions.all(), &Permissions.bit/1)

      assert length(Enum.uniq(bits)) == length(bits)
      assert Enum.all?(bits, fn bit -> Bitwise.band(bit, bit - 1) == 0 end)
    end

    test "raises on unknown permission" do
      assert_raise KeyError, fn -> Permissions.bit(:fly) end
    end
  end

  describe "combine/1 and resolve/1" do
    test "combines permission names into a bitfield" do
      bitfield = Permissions.combine([:send_messages, :kick_members])

      assert Permissions.has?(bitfield, :send_messages)
      assert Permissions.has?(bitfield, :kick_members)
      refute Permissions.has?(bitfield, :ban_members)
    end

    test "resolves several role bitfields into effective permissions" do
      moderator = Permissions.combine([:kick_members, :manage_messages])
      member = Permissions.combine([:send_messages])

      effective = Permissions.resolve([moderator, member])

      assert Permissions.has?(effective, :kick_members)
      assert Permissions.has?(effective, :send_messages)
      refute Permissions.has?(effective, :manage_roles)
    end

    test "resolve of no roles grants nothing" do
      effective = Permissions.resolve([])

      refute Enum.any?(Permissions.all(), &Permissions.has?(effective, &1))
    end
  end

  describe "has?/2" do
    test "administrator grants every permission" do
      bitfield = Permissions.combine([:administrator])

      assert Enum.all?(Permissions.all(), &Permissions.has?(bitfield, &1))
    end

    test "a plain bitfield only grants its own bits" do
      bitfield = Permissions.combine([:manage_channels])

      assert Permissions.has?(bitfield, :manage_channels)
      refute Permissions.has?(bitfield, :manage_community)
      refute Permissions.admin?(bitfield)
    end
  end

  describe "default/0" do
    test "grants messaging and invites, nothing else" do
      default = Permissions.default()

      assert Permissions.has?(default, :send_messages)
      assert Permissions.has?(default, :create_invites)
      refute Permissions.has?(default, :kick_members)
      refute Permissions.has?(default, :manage_community)
      refute Permissions.admin?(default)
    end
  end

  describe "hierarchy" do
    test "acting requires a strictly higher position" do
      assert Permissions.can_act_on?(2, 1)
      refute Permissions.can_act_on?(1, 1)
      refute Permissions.can_act_on?(1, 2)
    end

    test "top_position picks the highest role, 0 without roles" do
      assert Permissions.top_position([%{position: 1}, %{position: 5}, %{position: 3}]) == 5
      assert Permissions.top_position([]) == 0
    end
  end
end
