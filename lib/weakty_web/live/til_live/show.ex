defmodule WeaktyWeb.TilLive.Show do
  use WeaktyWeb, :live_view

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    til =
      Weakty.Posts.Post
      |> Ash.Query.for_read(:get_by_slug, %{slug: slug})
      |> Ash.read_one!()
      |> Ash.load!(:tags)

    if is_nil(til) or (not til.public and is_nil(socket.assigns[:current_user])) do
      {:ok, push_navigate(socket, to: ~p"/til")}
    else
      {:ok,
       socket
       |> assign(til: til)
       |> assign(page_title: til.title)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container>
      <article>
        <header class="mb-8">
          <div class="text-xs uppercase tracking-widest mb-4 opacity-40">TIL</div>
          <h1 class="text-2xl font-normal averia mb-3">{@til.title}</h1>
          <time class="text-sm opacity-40 tabular-nums">
            {if @til.published_at, do: Calendar.strftime(@til.published_at, "%Y-%m-%d")}
          </time>
        </header>

        <%= if @til.html do %>
          <div class="prose prose-sm max-w-none opacity-80">
            {Phoenix.HTML.raw(@til.html)}
          </div>
        <% else %>
          <p class="opacity-80 leading-relaxed">{@til.markdown}</p>
        <% end %>

        <%= if @til.tags && length(@til.tags) > 0 do %>
          <div class="flex flex-wrap gap-3 text-xs opacity-40 mt-8">
            <%= for tag <- @til.tags do %>
              <span>#{tag.name}</span>
            <% end %>
          </div>
        <% end %>
      </article>
    </.page_container>
    """
  end
end
