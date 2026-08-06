defmodule RChatWeb.JoinLive do
  use RChatWeb, :live_view

  alias RChat.Communities

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm text-center space-y-4">
        <%= if @status == :valid do %>
          <p class="text-sm text-muted">You were invited to join</p>
          <h1 class="text-2xl font-semibold">{@invite.community.name}</h1>
          <p :if={@invite.community.description} class="text-sm text-muted">
            {@invite.community.description}
          </p>
          <p class="text-xs text-muted">
            {@member_count} {if @member_count == 1, do: "member", else: "members"}
          </p>

          <%= if @current_scope do %>
            <.button phx-click="join" class="btn btn-primary w-full">
              Join {@invite.community.name}
            </.button>
          <% else %>
            <.link navigate={~p"/users/register?invite=#{@code}"} class="btn btn-primary w-full">
              Create an account
            </.link>
            <.link
              navigate={~p"/users/log-in?return_to=/join/#{@code}"}
              class="btn btn-ghost w-full"
            >
              I already have an account
            </.link>
          <% end %>
        <% else %>
          <h1 class="text-2xl font-semibold">Invalid invite</h1>
          <p class="text-sm text-muted">This invite link is invalid or has expired.</p>
          <.link navigate={~p"/"} class="font-semibold text-brand hover:underline">
            Back to RChat
          </.link>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    invite = Communities.get_invite_by_code(code)

    status =
      if invite && Communities.invite_status(invite) == :valid, do: :valid, else: :invalid

    {:ok,
     assign(socket,
       page_title: "Join",
       code: code,
       invite: invite,
       status: status,
       member_count: if(status == :valid, do: Communities.count_members(invite.community))
     )}
  end

  @impl true
  def handle_event("join", _params, socket) do
    case Communities.accept_invite(socket.assigns.current_scope, socket.assigns.code) do
      {:ok, community} ->
        {:noreply,
         socket
         |> put_flash(:info, "Welcome to #{community.name}!")
         |> push_navigate(to: ~p"/c/#{community.slug}")}

      {:error, :already_member} ->
        {:noreply, push_navigate(socket, to: ~p"/c/#{socket.assigns.invite.community.slug}")}

      {:error, _reason} ->
        {:noreply, assign(socket, status: :invalid)}
    end
  end
end
