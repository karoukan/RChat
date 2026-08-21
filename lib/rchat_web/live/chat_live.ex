defmodule RChatWeb.ChatLive do
  use RChatWeb, :live_view

  alias RChat.Chat
  alias RChat.Communities
  alias RChat.Communities.{Channel, Community}

  @page_size 50

  @impl true
  def render(assigns) do
    ~H"""
    <div id="chat-root" phx-hook=".ChannelNav" class="flex h-screen bg-base-100 text-base-content">
      <nav class="w-16 shrink-0 bg-base-300 flex flex-col items-center gap-2 py-3 overflow-y-auto">
        <.link
          :for={community <- @communities}
          patch={~p"/c/#{community.slug}"}
          title={community.name}
          class={[
            "relative flex size-11 shrink-0 items-center justify-center rounded-full text-sm font-semibold transition-colors",
            if(@current_community && @current_community.id == community.id,
              do: "bg-primary text-primary-content",
              else: "bg-base-100 text-muted hover:text-base-content"
            )
          ]}
        >
          {initials(community.name)}
          <span
            :if={rail_unread?(community, @current_community, @unread_channels, @unread_communities)}
            class="absolute -left-2.5 top-1/2 -translate-y-1/2 h-3 w-1 rounded-r-full bg-base-content"
          ></span>
        </.link>
        <.link
          patch={~p"/communities/new"}
          title="New community"
          class="flex size-11 shrink-0 items-center justify-center rounded-full bg-base-100 text-muted hover:text-primary"
        >
          <.icon name="hero-plus" class="size-5" />
          <span class="sr-only">New community</span>
        </.link>
      </nav>

      <aside
        id="sidebar"
        class="w-60 shrink-0 bg-base-200 border-r border-subtle flex flex-col max-md:hidden max-md:absolute max-md:inset-y-0 max-md:left-16 max-md:z-20"
      >
        <div class="h-12 shrink-0 border-b border-subtle px-4 flex items-center font-semibold">
          <span class="truncate">
            {if @current_community, do: @current_community.name, else: "RChat"}
          </span>
        </div>
        <div class="flex-1 overflow-y-auto py-2 px-2 space-y-0.5">
          <%= if @current_community do %>
            <.link
              :for={channel <- @channels}
              patch={~p"/c/#{@current_community.slug}/#{channel.id}"}
              class={[
                "flex items-center gap-1.5 rounded px-2 py-1 text-sm",
                channel_class(channel, @current_channel, @unread_channels)
              ]}
            >
              <span class="opacity-60">#</span>{channel.name}
            </.link>
            <.link
              :if={@can_manage_channels}
              patch={~p"/c/#{@current_community.slug}/channels/new"}
              class="flex items-center gap-1.5 rounded px-2 py-1 text-sm text-muted hover:text-base-content"
            >
              <.icon name="hero-plus" class="size-4" /> New channel
            </.link>
            <.link
              :if={@can_invite}
              patch={~p"/c/#{@current_community.slug}/invite"}
              class="flex items-center gap-1.5 rounded px-2 py-1 text-sm text-muted hover:text-base-content"
            >
              <.icon name="hero-user-plus" class="size-4" /> Invite people
            </.link>
          <% end %>
        </div>
        <div class="h-12 shrink-0 border-t border-subtle px-3 flex items-center gap-2">
          <span class="text-sm font-medium truncate flex-1">{@current_scope.user.username}</span>
          <.link
            href={~p"/users/settings"}
            title="Settings"
            class="text-muted hover:text-base-content"
          >
            <.icon name="hero-cog-6-tooth" class="size-5" />
            <span class="sr-only">Settings</span>
          </.link>
          <.link
            href={~p"/users/log-out"}
            method="delete"
            title="Log out"
            class="text-muted hover:text-base-content"
          >
            <.icon name="hero-arrow-right-start-on-rectangle" class="size-5" />
            <span class="sr-only">Log out</span>
          </.link>
        </div>
      </aside>

      <main class="flex-1 min-w-0 flex flex-col">
        <%= cond do %>
          <% @live_action == :new_community -> %>
            <div class="flex-1 grid place-items-center p-6">
              <div class="w-full max-w-sm space-y-4">
                <h1 class="text-lg font-semibold">Create a community</h1>
                <.form
                  for={@form}
                  id="community_form"
                  phx-change="validate_community"
                  phx-submit="create_community"
                >
                  <.input
                    field={@form[:name]}
                    type="text"
                    label="Name"
                    required
                    phx-mounted={JS.focus()}
                  />
                  <.input field={@form[:description]} type="textarea" label="Description" />
                  <.button phx-disable-with="Creating..." class="btn btn-primary w-full">
                    Create
                  </.button>
                </.form>
              </div>
            </div>
          <% @live_action == :new_channel -> %>
            <div class="flex-1 grid place-items-center p-6">
              <div class="w-full max-w-sm space-y-4">
                <h1 class="text-lg font-semibold">Create a channel</h1>
                <.form
                  for={@form}
                  id="channel_form"
                  phx-change="validate_channel"
                  phx-submit="create_channel"
                >
                  <.input
                    field={@form[:name]}
                    type="text"
                    label="Name"
                    required
                    phx-mounted={JS.focus()}
                  />
                  <.input field={@form[:topic]} type="text" label="Topic" />
                  <.button phx-disable-with="Creating..." class="btn btn-primary w-full">
                    Create
                  </.button>
                </.form>
              </div>
            </div>
          <% @live_action == :invite -> %>
            <div class="flex-1 overflow-y-auto p-6">
              <div class="w-full max-w-md mx-auto space-y-6">
                <h1 class="text-lg font-semibold">Invite people to {@current_community.name}</h1>

                <form phx-submit="create_invite" class="space-y-3">
                  <div class="grid grid-cols-2 gap-3">
                    <label class="text-sm space-y-1">
                      <span class="text-muted">Expires after</span>
                      <select name="expires_in" class="select w-full">
                        <option value="1h">1 hour</option>
                        <option value="1d">1 day</option>
                        <option value="7d" selected>7 days</option>
                        <option value="never">Never</option>
                      </select>
                    </label>
                    <label class="text-sm space-y-1">
                      <span class="text-muted">Max uses</span>
                      <select name="max_uses" class="select w-full">
                        <option value="">No limit</option>
                        <option value="1">1</option>
                        <option value="10">10</option>
                        <option value="25">25</option>
                      </select>
                    </label>
                  </div>
                  <.button class="btn btn-primary w-full">Generate invite link</.button>
                </form>

                <div :if={@created_invite} class="space-y-2">
                  <p class="text-sm text-muted">Share this link:</p>
                  <div class="flex gap-2">
                    <input
                      id="invite-url"
                      type="text"
                      readonly
                      value={url(~p"/join/#{@created_invite.code}")}
                      class="input flex-1 font-mono text-sm"
                    />
                    <button
                      type="button"
                      id="copy-invite"
                      phx-hook=".Copy"
                      data-target="invite-url"
                      class="btn"
                    >
                      Copy
                    </button>
                  </div>
                </div>

                <div :if={@active_invites != []} class="space-y-2">
                  <p class="text-sm font-semibold text-muted">Active invites</p>
                  <div
                    :for={invite <- @active_invites}
                    class="flex items-center justify-between rounded border border-subtle px-3 py-2 text-sm"
                  >
                    <span class="font-mono">{invite.code}</span>
                    <span class="text-muted">
                      {invite.uses}{if invite.max_uses, do: "/#{invite.max_uses}"} uses, {if invite.expires_at,
                        do: "expires #{Calendar.strftime(invite.expires_at, "%d/%m %H:%M")}",
                        else: "never expires"}
                    </span>
                  </div>
                </div>
              </div>
            </div>
            <script :type={Phoenix.LiveView.ColocatedHook} name=".Copy">
              export default {
                mounted() {
                  this.el.addEventListener("click", () => {
                    const input = document.getElementById(this.el.dataset.target)
                    navigator.clipboard.writeText(input.value)
                    this.el.textContent = "Copied"
                    setTimeout(() => { this.el.textContent = "Copy" }, 1500)
                  })
                }
              }
            </script>
          <% @current_channel -> %>
            <div class="h-12 shrink-0 border-b border-subtle px-4 flex items-center gap-2 min-w-0">
              <button
                type="button"
                class="md:hidden text-muted hover:text-base-content"
                phx-click={JS.toggle_class("max-md:hidden", to: "#sidebar")}
              >
                <.icon name="hero-bars-3" class="size-5" />
                <span class="sr-only">Toggle channels</span>
              </button>
              <span class="font-semibold">
                <span class="opacity-60">#</span>{@current_channel.name}
              </span>
              <span
                :if={@current_channel.topic}
                class="text-sm text-muted truncate border-l border-subtle pl-2"
              >
                {@current_channel.topic}
              </span>
              <span class="ml-auto flex items-center gap-1.5 text-xs text-muted whitespace-nowrap">
                <span class="size-2 rounded-full bg-success"></span>
                {MapSet.size(@online)} online
              </span>
            </div>
            <div class="relative flex-1 min-h-0 flex flex-col">
              <div
                id="messages-scroll"
                phx-hook=".ScrollManager"
                data-channel-id={@current_channel.id}
                data-first-unread={@first_unread_id && "messages-#{@first_unread_id}"}
                class="flex-1 overflow-y-auto px-4 py-4 flex flex-col"
              >
                <div
                  id="messages"
                  phx-update="stream"
                  phx-viewport-top={!@history_end && "load_older"}
                  class="mt-auto"
                >
                  <div id="messages-empty" class="hidden only:block pt-2 text-sm text-muted">
                    This is the beginning of <span class="font-medium">#{@current_channel.name}</span>.
                  </div>
                  <div
                    :for={{dom_id, item} <- @streams.messages}
                    id={dom_id}
                    class={["group", if(item.compact, do: "mt-0.5", else: "mt-4 first:mt-0")]}
                  >
                    <div
                      :if={item.divider}
                      class="flex items-center gap-3 mb-4 text-[11px] text-muted"
                    >
                      <span class="h-px flex-1 bg-subtle"></span>
                      <time
                        id={"divider-#{dom_id}"}
                        phx-hook=".LocalTime"
                        data-kind="date"
                        data-ts={Date.to_iso8601(item.divider)}
                      >
                        {Calendar.strftime(item.divider, "%d/%m/%Y")}
                      </time>
                      <span class="h-px flex-1 bg-subtle"></span>
                    </div>
                    <div :if={item.compact} class="flex gap-3">
                      <div class="w-9 shrink-0 text-right text-[10px] leading-6 text-muted opacity-0 group-hover:opacity-100">
                        <time
                          id={"time-#{dom_id}"}
                          phx-hook=".LocalTime"
                          data-ts={DateTime.to_iso8601(item.message.inserted_at)}
                        >
                          {format_time(item.message.inserted_at)}
                        </time>
                      </div>
                      <p
                        class="flex-1 min-w-0 text-sm whitespace-pre-wrap break-words"
                        phx-no-format
                      >{item.message.content}</p>
                    </div>
                    <div :if={!item.compact} class="flex gap-3">
                      <div class={[
                        "size-9 shrink-0 rounded-full flex items-center justify-center text-sm font-semibold",
                        avatar_color(item.message.author)
                      ]}>
                        {avatar_initial(item.message.author)}
                      </div>
                      <div class="flex-1 min-w-0">
                        <div class="flex items-baseline gap-2">
                          <span class="text-sm font-semibold">{author_name(item.message.author)}</span>
                          <time
                            id={"time-#{dom_id}"}
                            phx-hook=".LocalTime"
                            class="text-[11px] text-muted"
                            data-ts={DateTime.to_iso8601(item.message.inserted_at)}
                          >
                            {format_time(item.message.inserted_at)}
                          </time>
                        </div>
                        <p class="text-sm whitespace-pre-wrap break-words" phx-no-format>{item.message.content}</p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <button
                id="new-messages-pill"
                type="button"
                class="hidden absolute bottom-3 left-1/2 -translate-x-1/2 btn btn-primary btn-xs rounded-full"
              ></button>
            </div>
            <form
              id="composer"
              phx-submit="send_message"
              phx-hook=".Composer"
              class="shrink-0 p-3 flex items-end gap-2"
            >
              <textarea
                name="content"
                rows="1"
                class="textarea w-full resize-none leading-5"
                placeholder={"Message ##{@current_channel.name}"}
                autocomplete="off"
                maxlength="4000"
                required
              ></textarea>
              <button type="submit" class="btn btn-primary hidden pointer-coarse:inline-flex">
                <.icon name="hero-paper-airplane" class="size-5" />
                <span class="sr-only">Send</span>
              </button>
            </form>
            <script :type={Phoenix.LiveView.ColocatedHook} name=".ScrollManager">
              export default {
                mounted() {
                  this.pill = document.getElementById("new-messages-pill")
                  this.channelId = this.el.dataset.channelId
                  this.count = 0
                  this.lastChildren = this.childCount()
                  this.el.addEventListener("scroll", () => {
                    if (this.nearBottom()) this.hidePill()
                  })
                  this.pill.addEventListener("click", () => {
                    this.scrollBottom()
                    this.hidePill()
                  })
                  this.scrollToTarget()
                },
                beforeUpdate() {
                  this.follow = this.nearBottom()
                  this.prevHeight = this.el.scrollHeight
                  this.prevFirstId = this.firstMessageId()
                },
                updated() {
                  if (this.channelId !== this.el.dataset.channelId) {
                    this.channelId = this.el.dataset.channelId
                    this.lastChildren = this.childCount()
                    this.hidePill()
                    this.scrollToTarget()
                    return
                  }
                  const children = this.childCount()
                  const added = Math.max(0, children - this.lastChildren)
                  this.lastChildren = children
                  const prepended =
                    this.prevFirstId && this.firstMessageId() !== this.prevFirstId && added > 0
                  if (prepended && !this.follow) {
                    this.el.scrollTop += this.el.scrollHeight - this.prevHeight
                  } else if (this.follow) {
                    this.scrollBottom()
                  } else if (added > 0) {
                    this.count += added
                    this.pill.textContent =
                      this.count === 1 ? "1 new message" : `${this.count} new messages`
                    this.pill.classList.remove("hidden")
                  }
                },
                firstMessageId() {
                  const items = document.getElementById("messages").children
                  for (const el of items) {
                    if (/^messages-\d+$/.test(el.id)) return el.id
                  }
                  return null
                },
                childCount() { return document.getElementById("messages").childElementCount },
                nearBottom() {
                  return this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight < 120
                },
                scrollBottom() { this.el.scrollTop = this.el.scrollHeight },
                scrollToTarget() {
                  const targetId = this.el.dataset.firstUnread
                  const target = targetId && document.getElementById(targetId)
                  if (target) {
                    target.scrollIntoView({block: "center"})
                  } else {
                    this.scrollBottom()
                  }
                },
                hidePill() { this.count = 0; this.pill.classList.add("hidden") }
              }
            </script>
            <script :type={Phoenix.LiveView.ColocatedHook} name=".Composer">
              export default {
                mounted() {
                  this.textarea = this.el.querySelector("textarea")
                  this.coarse = window.matchMedia("(pointer: coarse)").matches

                  this.el.addEventListener("submit", () => {
                    requestAnimationFrame(() => {
                      this.el.reset()
                      this.autogrow()
                      this.textarea.focus()
                    })
                  })

                  this.textarea.addEventListener("keydown", e => {
                    if (e.key === "Enter" && !e.shiftKey && !e.isComposing && !this.coarse) {
                      e.preventDefault()
                      if (this.textarea.value.trim() !== "") {
                        this.el.dispatchEvent(new Event("submit", {bubbles: true, cancelable: true}))
                      }
                    }
                  })
                  this.textarea.addEventListener("input", () => this.autogrow())

                  this.refocus = e => {
                    if (e.metaKey || e.ctrlKey || e.altKey || e.key.length !== 1) return
                    const t = e.target
                    if (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.isContentEditable) return
                    this.textarea.focus()
                  }
                  window.addEventListener("keydown", this.refocus)

                  this.textarea.focus()
                  this.autogrow()
                },
                updated() {
                  if (document.activeElement === document.body) this.textarea.focus()
                },
                destroyed() {
                  window.removeEventListener("keydown", this.refocus)
                },
                autogrow() {
                  const ta = this.textarea
                  ta.style.height = "auto"
                  const line = parseFloat(getComputedStyle(ta).lineHeight) || 20
                  const max = line * 8 + 16
                  ta.style.height = Math.min(ta.scrollHeight, max) + "px"
                  ta.style.overflowY = ta.scrollHeight > max ? "auto" : "hidden"
                }
              }
            </script>
            <script :type={Phoenix.LiveView.ColocatedHook} name=".LocalTime">
              export default {
                mounted() { this.format() },
                updated() { this.format() },
                format() {
                  const ts = this.el.dataset.ts
                  if (this.el.dataset.kind === "date") {
                    const [y, m, d] = ts.split("-").map(Number)
                    const date = new Date(y, m - 1, d)
                    const today = new Date()
                    today.setHours(0, 0, 0, 0)
                    const diff = Math.round((date - today) / 86400000)
                    if (diff === 0 || diff === -1) {
                      const label = new Intl.RelativeTimeFormat([], {numeric: "auto"}).format(diff, "day")
                      this.el.textContent = label.charAt(0).toUpperCase() + label.slice(1)
                    } else {
                      this.el.textContent = new Intl.DateTimeFormat([], {dateStyle: "long"}).format(date)
                    }
                  } else {
                    this.el.textContent =
                      new Intl.DateTimeFormat([], {timeStyle: "short"}).format(new Date(ts))
                  }
                }
              }
            </script>
            <script :type={Phoenix.LiveView.ColocatedHook} name=".ChannelNav">
              export default {
                mounted() {
                  this.onKey = e => {
                    if (e.altKey && !e.shiftKey && (e.key === "ArrowUp" || e.key === "ArrowDown")) {
                      e.preventDefault()
                      this.pushEvent("channel_nav", {dir: e.key === "ArrowUp" ? "prev" : "next"})
                    } else if (e.key === "Escape" && !e.altKey && !e.ctrlKey && !e.metaKey) {
                      this.pushEvent("mark_read", {})
                    }
                  }
                  window.addEventListener("keydown", this.onKey)
                },
                destroyed() { window.removeEventListener("keydown", this.onKey) }
              }
            </script>
          <% true -> %>
            <div class="flex-1 grid place-items-center p-6">
              <div class="text-center space-y-3">
                <img src={~p"/images/logo.svg"} width="48" class="mx-auto" alt="" />
                <h1 class="text-lg font-semibold">Welcome to RChat</h1>
                <p class="text-sm text-muted">Create your first community to get started.</p>
                <.link patch={~p"/communities/new"} class="btn btn-primary">
                  Create a community
                </.link>
              </div>
            </div>
        <% end %>
      </main>

      <aside
        :if={@current_community && @live_action == :community}
        class="w-56 shrink-0 bg-base-200 border-l border-subtle hidden lg:flex flex-col"
      >
        <div class="h-12 shrink-0 border-b border-subtle px-4 flex items-center text-sm font-semibold text-muted">
          Members ({length(@members)})
        </div>
        <div class="flex-1 overflow-y-auto py-2 px-2 space-y-0.5">
          <div
            :for={member <- @members}
            class="flex items-center gap-2 px-2 py-1 text-sm"
          >
            <div class="relative shrink-0">
              <div class={[
                "size-7 rounded-full flex items-center justify-center text-xs font-semibold",
                avatar_color(member.user)
              ]}>
                {avatar_initial(member.user)}
              </div>
              <span class={[
                "absolute -bottom-0.5 -right-0.5 size-2.5 rounded-full border-2 border-base-200",
                if(MapSet.member?(@online, to_string(member.user_id)),
                  do: "bg-success",
                  else: "bg-base-300"
                )
              ]}></span>
            </div>
            <span class="truncate text-muted">{member.nickname || member.user.username}</span>
          </div>
        </div>
      </aside>
    </div>
    <Layouts.flash_group flash={@flash} />
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    communities = Communities.list_communities(scope)

    if connected?(socket), do: Enum.each(communities, &Chat.subscribe_community/1)

    {:ok,
     socket
     |> assign(
       communities: communities,
       current_community: nil,
       channels: [],
       current_channel: nil,
       members: [],
       can_manage_channels: false,
       can_invite: false,
       active_invites: [],
       created_invite: nil,
       form: nil,
       last_message: nil,
       first_message: nil,
       first_unread_id: nil,
       history_end: true,
       unread_channels: MapSet.new(),
       unread_communities: Chat.unread_community_ids(scope),
       presence_community: nil,
       online: MapSet.new()
     )
     |> stream(:messages, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    case socket.assigns.communities do
      [community | _] ->
        push_patch(socket, to: ~p"/c/#{community.slug}")

      [] ->
        assign(socket,
          page_title: "RChat",
          current_community: nil,
          channels: [],
          current_channel: nil,
          members: []
        )
    end
  end

  defp apply_action(socket, :new_community, _params) do
    assign(socket,
      page_title: "New community",
      current_community: nil,
      channels: [],
      current_channel: nil,
      members: [],
      form: to_form(Communities.change_community(%Community{}))
    )
  end

  defp apply_action(socket, :community, %{"slug" => slug} = params) do
    scope = socket.assigns.current_scope
    community = Communities.get_community!(scope, slug)
    channels = Communities.list_channels(community)

    current_channel =
      case params["channel_id"] do
        nil -> List.first(channels)
        id -> Communities.get_channel!(community, id)
      end

    messages =
      if current_channel, do: Chat.list_messages(current_channel, limit: @page_size), else: []

    {items, last_message} = group_messages(messages)

    first_unread_id = current_channel && Chat.first_unread_id(scope, current_channel)

    if current_channel && connected?(socket) do
      Chat.mark_channel_read(scope, current_channel)
    end

    unread_channels =
      scope |> Chat.unread_channel_ids(community) |> maybe_delete(current_channel)

    socket
    |> assign(
      page_title: if(current_channel, do: "##{current_channel.name}", else: community.name),
      current_community: community,
      channels: channels,
      current_channel: current_channel,
      members: Communities.list_members(community),
      can_manage_channels: Communities.permitted?(scope, community, :manage_channels),
      can_invite: Communities.permitted?(scope, community, :create_invites),
      last_message: last_message,
      first_message: List.first(messages),
      first_unread_id: first_unread_id,
      history_end: length(messages) < @page_size,
      unread_channels: unread_channels,
      unread_communities: Chat.unread_community_ids(scope)
    )
    |> maybe_track_presence(community)
    |> stream(:messages, items, reset: true)
  end

  defp apply_action(socket, :invite, %{"slug" => slug}) do
    scope = socket.assigns.current_scope
    community = Communities.get_community!(scope, slug)

    if Communities.permitted?(scope, community, :create_invites) do
      assign(socket,
        page_title: "Invite people",
        current_community: community,
        channels: Communities.list_channels(community),
        current_channel: nil,
        members: Communities.list_members(community),
        can_manage_channels: Communities.permitted?(scope, community, :manage_channels),
        can_invite: true,
        active_invites: Communities.list_active_invites(scope, community),
        created_invite: nil
      )
    else
      socket
      |> put_flash(:error, "You are not allowed to create invites.")
      |> push_patch(to: ~p"/c/#{community.slug}")
    end
  end

  defp apply_action(socket, :new_channel, %{"slug" => slug}) do
    scope = socket.assigns.current_scope
    community = Communities.get_community!(scope, slug)

    if Communities.permitted?(scope, community, :manage_channels) do
      assign(socket,
        page_title: "New channel",
        current_community: community,
        channels: Communities.list_channels(community),
        current_channel: nil,
        members: Communities.list_members(community),
        can_manage_channels: true,
        form: to_form(Communities.change_channel(%Channel{}))
      )
    else
      socket
      |> put_flash(:error, "You are not allowed to manage channels.")
      |> push_patch(to: ~p"/c/#{community.slug}")
    end
  end

  @impl true
  def handle_event("validate_community", %{"community" => attrs}, socket) do
    changeset = Communities.change_community(%Community{}, attrs)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("create_community", %{"community" => attrs}, socket) do
    case Communities.create_community(socket.assigns.current_scope, attrs) do
      {:ok, community} ->
        if connected?(socket), do: Chat.subscribe_community(community)

        {:noreply,
         socket
         |> assign(communities: Communities.list_communities(socket.assigns.current_scope))
         |> push_patch(to: ~p"/c/#{community.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_channel", %{"channel" => attrs}, socket) do
    changeset = Communities.change_channel(%Channel{}, attrs)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("create_channel", %{"channel" => attrs}, socket) do
    %{current_scope: scope, current_community: community} = socket.assigns

    case Communities.create_channel(scope, community, attrs) do
      {:ok, channel} ->
        {:noreply, push_patch(socket, to: ~p"/c/#{community.slug}/#{channel.id}")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not allowed to manage channels.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :insert))}
    end
  end

  def handle_event("create_invite", params, socket) do
    %{current_scope: scope, current_community: community} = socket.assigns
    attrs = %{expires_at: parse_expiry(params["expires_in"]), max_uses: parse_max_uses(params)}

    case Communities.create_invite(scope, community, attrs) do
      {:ok, invite} ->
        {:noreply,
         assign(socket,
           created_invite: invite,
           active_invites: Communities.list_active_invites(scope, community)
         )}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not allowed to create invites.")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, "Could not create this invite.")}
    end
  end

  def handle_event("send_message", %{"content" => content}, socket) do
    %{current_scope: scope, current_community: community, current_channel: channel} =
      socket.assigns

    case String.trim(content) do
      "" ->
        {:noreply, socket}

      content ->
        case Chat.create_message(scope, community, channel, %{content: content}) do
          {:ok, _message} ->
            {:noreply, socket}

          {:error, :unauthorized} ->
            {:noreply, put_flash(socket, :error, "You are not allowed to send messages here.")}

          {:error, %Ecto.Changeset{}} ->
            {:noreply, socket}
        end
    end
  end

  def handle_event("load_older", _params, socket) do
    %{current_channel: channel, first_message: first, history_end: history_end} = socket.assigns

    if channel && first && !history_end do
      older = Chat.list_messages(channel, before: first.id, limit: @page_size)
      {items, last_of_batch} = group_messages(older)

      socket =
        items
        |> Enum.reverse()
        |> Enum.reduce(socket, fn item, acc -> stream_insert(acc, :messages, item, at: 0) end)

      socket =
        if last_of_batch do
          stream_insert(socket, :messages, message_item(first, last_of_batch), at: length(items))
        else
          socket
        end

      {:noreply,
       assign(socket,
         first_message: List.first(older) || first,
         history_end: length(older) < @page_size
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("mark_read", _params, socket) do
    if channel = socket.assigns.current_channel do
      Chat.mark_channel_read(socket.assigns.current_scope, channel)
    end

    {:noreply, socket}
  end

  def handle_event("channel_nav", %{"dir" => dir}, socket) do
    %{channels: channels, current_channel: current, current_community: community} =
      socket.assigns

    if community && channels != [] do
      count = length(channels)
      index = current && Enum.find_index(channels, &(&1.id == current.id))

      next_index =
        case {index, dir} do
          {nil, _} -> 0
          {i, "next"} -> rem(i + 1, count)
          {i, _} -> rem(i - 1 + count, count)
        end

      channel = Enum.at(channels, next_index)
      {:noreply, push_patch(socket, to: ~p"/c/#{community.slug}/#{channel.id}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    case socket.assigns.presence_community do
      nil ->
        {:noreply, socket}

      community ->
        online =
          community
          |> presence_topic()
          |> RChatWeb.Presence.list()
          |> Map.keys()
          |> MapSet.new()

        {:noreply, assign(socket, online: online)}
    end
  end

  def handle_info({:message_created, message}, socket) do
    %{
      current_channel: current_channel,
      current_community: current_community,
      last_message: last_message
    } = socket.assigns

    cond do
      current_channel && message.channel_id == current_channel.id ->
        Chat.mark_channel_read(socket.assigns.current_scope, current_channel)

        {:noreply,
         socket
         |> stream_insert(:messages, message_item(message, last_message))
         |> assign(last_message: message)}

      current_community && message.channel.community_id == current_community.id ->
        {:noreply, update(socket, :unread_channels, &MapSet.put(&1, message.channel_id))}

      true ->
        {:noreply,
         update(socket, :unread_communities, &MapSet.put(&1, message.channel.community_id))}
    end
  end

  defp maybe_delete(set, nil), do: set
  defp maybe_delete(set, %Channel{id: id}), do: MapSet.delete(set, id)

  defp rail_unread?(community, current_community, unread_channels, unread_communities) do
    if current_community && current_community.id == community.id do
      MapSet.size(unread_channels) > 0
    else
      community.id in unread_communities
    end
  end

  defp channel_class(channel, current_channel, unread_channels) do
    cond do
      current_channel && current_channel.id == channel.id ->
        "bg-base-300 text-base-content"

      channel.id in unread_channels ->
        "text-base-content font-semibold hover:bg-base-300/50"

      true ->
        "text-muted hover:bg-base-300/50 hover:text-base-content"
    end
  end

  defp presence_topic(community), do: "presence:community:#{community.id}"

  defp maybe_track_presence(socket, community) do
    previous = socket.assigns.presence_community

    cond do
      not connected?(socket) ->
        socket

      previous && previous.id == community.id ->
        socket

      true ->
        user = socket.assigns.current_scope.user

        if previous do
          RChatWeb.Presence.untrack(self(), presence_topic(previous), to_string(user.id))
          Phoenix.PubSub.unsubscribe(RChat.PubSub, presence_topic(previous))
        end

        topic = presence_topic(community)
        Phoenix.PubSub.subscribe(RChat.PubSub, topic)

        {:ok, _} =
          RChatWeb.Presence.track(self(), topic, to_string(user.id), %{username: user.username})

        online = topic |> RChatWeb.Presence.list() |> Map.keys() |> MapSet.new()

        assign(socket, presence_community: community, online: online)
    end
  end

  defp group_messages(messages) do
    Enum.map_reduce(messages, nil, fn message, previous ->
      {message_item(message, previous), message}
    end)
  end

  defp message_item(message, previous) do
    divider = day_divider(message, previous)

    %{
      id: message.id,
      message: message,
      divider: divider,
      compact: is_nil(divider) and compact?(message, previous)
    }
  end

  defp day_divider(message, previous) do
    date = DateTime.to_date(message.inserted_at)

    if is_nil(previous) or DateTime.to_date(previous.inserted_at) != date do
      date
    end
  end

  defp compact?(_message, nil), do: false

  defp compact?(message, previous) do
    message.author_id == previous.author_id and
      DateTime.diff(message.inserted_at, previous.inserted_at, :second) < 300
  end

  defp format_time(datetime), do: Calendar.strftime(datetime, "%H:%M")

  defp parse_expiry("1h"), do: DateTime.add(DateTime.utc_now(:second), 1, :hour)
  defp parse_expiry("1d"), do: DateTime.add(DateTime.utc_now(:second), 1, :day)
  defp parse_expiry("7d"), do: DateTime.add(DateTime.utc_now(:second), 7, :day)
  defp parse_expiry(_), do: nil

  defp parse_max_uses(%{"max_uses" => value}) when value in ~w(1 10 25),
    do: String.to_integer(value)

  defp parse_max_uses(_), do: nil

  @avatar_colors [
    "bg-sky-900 text-sky-200",
    "bg-teal-900 text-teal-200",
    "bg-indigo-900 text-indigo-200",
    "bg-rose-900 text-rose-200",
    "bg-amber-900 text-amber-200",
    "bg-emerald-900 text-emerald-200"
  ]

  defp avatar_color(nil), do: "bg-base-300 text-muted"

  defp avatar_color(user) do
    Enum.at(@avatar_colors, :erlang.phash2(user.username, length(@avatar_colors)))
  end

  defp avatar_initial(nil), do: "?"
  defp avatar_initial(user), do: user.username |> String.first() |> String.upcase()

  defp author_name(nil), do: "deleted user"
  defp author_name(user), do: user.username

  defp initials(name) do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end
end
