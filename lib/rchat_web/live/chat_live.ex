defmodule RChatWeb.ChatLive do
  use RChatWeb, :live_view

  alias RChat.Chat
  alias RChat.Communities
  alias RChat.Communities.{Channel, Community}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen bg-base-100 text-base-content">
      <nav class="w-16 shrink-0 bg-base-300 flex flex-col items-center gap-2 py-3 overflow-y-auto">
        <.link
          :for={community <- @communities}
          patch={~p"/c/#{community.slug}"}
          title={community.name}
          class={[
            "flex size-11 shrink-0 items-center justify-center rounded-xl text-sm font-semibold transition-colors",
            if(@current_community && @current_community.id == community.id,
              do: "bg-primary text-primary-content",
              else: "bg-base-100 text-muted hover:text-base-content"
            )
          ]}
        >
          {initials(community.name)}
        </.link>
        <.link
          patch={~p"/communities/new"}
          title="New community"
          class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-base-100 text-muted hover:text-primary"
        >
          <.icon name="hero-plus" class="size-5" />
          <span class="sr-only">New community</span>
        </.link>
      </nav>

      <aside class="w-60 shrink-0 bg-base-200 border-r border-subtle flex flex-col">
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
                if(@current_channel && @current_channel.id == channel.id,
                  do: "bg-base-300 text-base-content",
                  else: "text-muted hover:bg-base-300/50 hover:text-base-content"
                )
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
            <div
              id="messages-scroll"
              phx-hook=".AutoScroll"
              class="flex-1 overflow-y-auto px-4 py-4 flex flex-col"
            >
              <div id="messages" phx-update="stream" class="mt-auto">
                <div id="messages-empty" class="hidden only:block pt-2 text-sm text-muted">
                  This is the beginning of <span class="font-medium">#{@current_channel.name}</span>.
                </div>
                <div
                  :for={{dom_id, item} <- @streams.messages}
                  id={dom_id}
                  class={["group", if(item.compact, do: "mt-0.5", else: "mt-4 first:mt-0")]}
                >
                  <div :if={item.divider} class="flex items-center gap-3 mb-4 text-[11px] text-muted">
                    <span class="h-px flex-1 bg-subtle"></span>
                    {Calendar.strftime(item.divider, "%d/%m/%Y")}
                    <span class="h-px flex-1 bg-subtle"></span>
                  </div>
                  <div :if={item.compact} class="flex gap-3">
                    <div class="w-9 shrink-0 text-right text-[10px] leading-6 text-muted opacity-0 group-hover:opacity-100">
                      {format_time(item.message.inserted_at)}
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
                        <span class="text-[11px] text-muted">
                          {format_time(item.message.inserted_at)}
                        </span>
                      </div>
                      <p class="text-sm whitespace-pre-wrap break-words" phx-no-format>{item.message.content}</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <form id="composer" phx-submit="send_message" phx-hook=".Composer" class="shrink-0 p-3">
              <input
                type="text"
                name="content"
                class="input w-full"
                placeholder={"Message ##{@current_channel.name}"}
                autocomplete="off"
                maxlength="4000"
                required
              />
            </form>
            <script :type={Phoenix.LiveView.ColocatedHook} name=".AutoScroll">
              export default {
                mounted() { this.scroll() },
                beforeUpdate() {
                  this.follow =
                    this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight < 120
                },
                updated() { if (this.follow) this.scroll() },
                scroll() { this.el.scrollTop = this.el.scrollHeight }
              }
            </script>
            <script :type={Phoenix.LiveView.ColocatedHook} name=".Composer">
              export default {
                mounted() {
                  this.el.addEventListener("submit", () => {
                    requestAnimationFrame(() => this.el.reset())
                  })
                }
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
            class="flex items-center gap-2 px-2 py-1 text-sm text-muted"
          >
            <span class={[
              "size-2 rounded-full",
              if(MapSet.member?(@online, to_string(member.user_id)),
                do: "bg-success",
                else: "bg-base-content/20"
              )
            ]}></span>
            <span class="truncate">{member.nickname || member.user.username}</span>
          </div>
        </div>
      </aside>
    </div>
    <Layouts.flash_group flash={@flash} />
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       communities: Communities.list_communities(socket.assigns.current_scope),
       current_community: nil,
       channels: [],
       current_channel: nil,
       members: [],
       can_manage_channels: false,
       can_invite: false,
       active_invites: [],
       created_invite: nil,
       form: nil,
       subscribed_channel: nil,
       last_message: nil,
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

    messages = if current_channel, do: Chat.list_messages(current_channel), else: []
    {items, last_message} = group_messages(messages)

    socket
    |> assign(
      page_title: if(current_channel, do: "##{current_channel.name}", else: community.name),
      current_community: community,
      channels: channels,
      current_channel: current_channel,
      members: Communities.list_members(community),
      can_manage_channels: Communities.permitted?(scope, community, :manage_channels),
      can_invite: Communities.permitted?(scope, community, :create_invites),
      last_message: last_message
    )
    |> maybe_subscribe(current_channel)
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

    case Chat.create_message(scope, community, channel, %{content: content}) do
      {:ok, _message} ->
        {:noreply, socket}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not allowed to send messages here.")}

      {:error, %Ecto.Changeset{}} ->
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
    %{current_channel: current_channel, last_message: last_message} = socket.assigns

    if current_channel && message.channel_id == current_channel.id do
      {:noreply,
       socket
       |> stream_insert(:messages, message_item(message, last_message))
       |> assign(last_message: message)}
    else
      {:noreply, socket}
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

  defp maybe_subscribe(socket, channel) do
    previous = socket.assigns.subscribed_channel

    cond do
      not connected?(socket) ->
        socket

      previous && channel && previous.id == channel.id ->
        socket

      true ->
        if previous, do: Chat.unsubscribe_channel(previous)
        if channel, do: Chat.subscribe_channel(channel)
        assign(socket, subscribed_channel: channel)
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
