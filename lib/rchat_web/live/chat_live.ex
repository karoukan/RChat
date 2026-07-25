defmodule RChatWeb.ChatLive do
  use RChatWeb, :live_view

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
            </div>
            <div class="flex-1 overflow-y-auto grid place-items-center">
              <div class="text-center text-sm text-muted space-y-1">
                <p class="font-medium text-base-content">
                  <span class="opacity-60">#</span>{@current_channel.name}
                </p>
                <p>This is the beginning of the channel.</p>
              </div>
            </div>
            <div class="shrink-0 p-3">
              <input
                type="text"
                class="input w-full"
                placeholder={"Message ##{@current_channel.name}"}
                disabled
              />
            </div>
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
            <span class="size-2 rounded-full bg-base-content/20"></span>
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
     assign(socket,
       communities: Communities.list_communities(socket.assigns.current_scope),
       current_community: nil,
       channels: [],
       current_channel: nil,
       members: [],
       can_manage_channels: false,
       form: nil
     )}
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

    assign(socket,
      page_title: if(current_channel, do: "##{current_channel.name}", else: community.name),
      current_community: community,
      channels: channels,
      current_channel: current_channel,
      members: Communities.list_members(community),
      can_manage_channels: Communities.permitted?(scope, community, :manage_channels)
    )
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

  defp initials(name) do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end
end
