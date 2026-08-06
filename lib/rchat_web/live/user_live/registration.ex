defmodule RChatWeb.UserLive.Registration do
  use RChatWeb, :live_view

  alias RChat.Accounts
  alias RChat.Accounts.{Scope, User}
  alias RChat.Communities

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div :if={@mode == :closed} class="text-center space-y-3">
          <.header>Invite only</.header>
          <p class="text-sm text-muted">
            Registration requires an invite link. Ask a member of a community
            on this server to send you one.
          </p>
          <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
            Log in
          </.link>
        </div>

        <div :if={@mode != :closed}>
          <div class="text-center">
            <.header>
              Create an account
              <:subtitle>
                <%= if @mode == :invite do %>
                  You were invited to join <span class="font-semibold">{@invite.community.name}</span>.
                <% else %>
                  You are creating the first account of this server.
                <% end %>
                Already registered?
                <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
                  Log in
                </.link>
              </:subtitle>
            </.header>
          </div>

          <.form
            for={@form}
            id="registration_form"
            action={~p"/users/log-in?_action=registered"}
            method="post"
            phx-submit="save"
            phx-change="validate"
            phx-trigger-action={@trigger_submit}
          >
            <.input
              field={@form[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              spellcheck="false"
              required
              phx-mounted={JS.focus()}
            />
            <.input
              field={@form[:username]}
              type="text"
              label="Username"
              autocomplete="nickname"
              spellcheck="false"
              required
            />
            <.input
              field={@form[:password]}
              type="password"
              label="Password"
              autocomplete="new-password"
              spellcheck="false"
              required
            />

            <.button phx-disable-with="Creating account..." class="btn btn-primary w-full">
              Create an account
            </.button>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: RChatWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(params, _session, socket) do
    {mode, invite} = registration_mode(params["invite"])
    changeset = Accounts.change_user_registration(%User{})

    {:ok,
     socket
     |> assign(mode: mode, invite: invite, invite_code: params["invite"], trigger_submit: false)
     |> assign_form(changeset)}
  end

  defp registration_mode(invite_code) do
    cond do
      not Accounts.has_users?() ->
        {:bootstrap, nil}

      invite = valid_invite(invite_code) ->
        {:invite, invite}

      true ->
        {:closed, nil}
    end
  end

  defp valid_invite(code) when is_binary(code) do
    with %{} = invite <- Communities.get_invite_by_code(code),
         :valid <- Communities.invite_status(invite) do
      invite
    else
      _ -> nil
    end
  end

  defp valid_invite(_), do: nil

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    {mode, invite} = registration_mode(socket.assigns.invite_code)

    with true <- mode != :closed,
         {:ok, user} <- Accounts.register_user(user_params) do
      if invite, do: Communities.accept_invite(Scope.for_user(user), invite.code)

      changeset = Accounts.change_user_registration(user, user_params)
      {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}
    else
      false ->
        {:noreply,
         socket
         |> assign(mode: :closed, invite: nil)
         |> put_flash(:error, "This invite link is no longer valid.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
