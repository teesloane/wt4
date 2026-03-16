defmodule WeaktyWeb.AdminLive.Dashboard do
  use WeaktyWeb, :live_view

  import WeaktyWeb.AdminComponents

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign(:current_path, "/admin")
     |> assign(:quick_search_query, "")
     |> assign(:quick_search_results, [])
     |> assign(:quick_added, [])
     |> load_stats(), layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_header title="Dashboard" subtitle="Overview of your content">
      <:actions>
        <div class="flex gap-2">
          <.link navigate="/admin/posts/new" class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="w-4 h-4" /> New Post
          </.link>
          <.link navigate="/admin/til/new" class="btn btn-sm">
            <.icon name="hero-plus" class="w-4 h-4" /> New TIL
          </.link>
          <.link navigate="/admin/quotes/new" class="btn btn-sm">
            <.icon name="hero-plus" class="w-4 h-4" /> New Quote
          </.link>
        </div>
      </:actions>
    </.admin_header>

    <div class="p-8 space-y-8">
      <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <.stat_card label="Total Posts" value={@stats.total_posts} />
        <.stat_card label="Published" value={@stats.published_posts} />
        <.stat_card label="Drafts" value={@stats.draft_posts} />
        <.stat_card label="Links" value={@stats.total_links} />
        <.stat_card label="TILs" value={@stats.total_tils} />
        <.stat_card label="Quotes" value={@stats.total_quotes} />
      </div>

      <!-- Quick Add Album -->
      <div class="card bg-base-200">
        <div class="card-body p-6">
          <h2 class="card-title text-base mb-4">Quick Add Album</h2>

          <form phx-submit="quick_search" phx-change="quick_search_change" class="join w-full max-w-md">
            <input
              type="text"
              name="q"
              value={@quick_search_query}
              placeholder="Search for an album..."
              class="input input-bordered input-sm join-item flex-1"
              autocomplete="off"
            />
            <button type="submit" class="btn btn-sm btn-secondary join-item">Search</button>
          </form>

          <%= if @quick_search_results != [] do %>
            <div class="space-y-1 mt-4 max-h-72 overflow-y-auto">
              <%= for result <- @quick_search_results do %>
                <div class="flex items-center gap-3 p-2 rounded hover:bg-base-300">
                  <%= if result.cover_url do %>
                    <img
                      src={result.cover_url}
                      alt={result.title}
                      class="w-10 h-10 object-cover rounded shrink-0"
                    />
                  <% else %>
                    <div class="w-10 h-10 bg-base-300 rounded shrink-0" />
                  <% end %>
                  <div class="flex-1 min-w-0">
                    <div class="font-medium text-xs truncate">{result.title}</div>
                    <div class="text-xs text-base-content/60 truncate">
                      {Enum.join(result.creators, ", ")}
                    </div>
                  </div>
                  <button
                    type="button"
                    phx-click={JS.push("quick_add_album", value: %{id: result.external_id})}
                    class="btn btn-xs btn-primary shrink-0"
                  >
                    Add
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>

          <%= if @quick_added != [] do %>
            <div class="mt-4 space-y-1">
              <%= for item <- @quick_added do %>
                <div class="flex items-center gap-2 text-sm text-success">
                  <.icon name="hero-check-circle" class="w-4 h-4 shrink-0" />
                  <span class="font-medium">{item.title}</span>
                  <%= if item.creator != "" do %>
                    <span class="opacity-60">— {item.creator}</span>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("quick_search_change", %{"q" => q}, socket) do
    {:noreply, assign(socket, :quick_search_query, q)}
  end

  def handle_event("quick_search", _params, socket) do
    case Weakty.Media.search(:music, socket.assigns.quick_search_query) do
      {:ok, results} -> {:noreply, assign(socket, :quick_search_results, results)}
      {:error, _} -> {:noreply, assign(socket, :quick_search_results, [])}
    end
  end

  def handle_event("quick_add_album", %{"id" => external_id}, socket) do
    result = Enum.find(socket.assigns.quick_search_results, &(&1.external_id == external_id))

    if result do
      creator = result.creators |> Enum.take(3) |> Enum.join(", ")

      attrs =
        %{
          title: result.title,
          creator: creator,
          media_type: :music,
          status: :consumed,
          date_consumed: Date.utc_today(),
          thumbnail_url: result.cover_url,
          public: true,
          user_id: socket.assigns.current_user.id
        }
        |> maybe_put_date_published(result.year)

      case Weakty.MediaLogs.MediaLog
           |> Ash.Changeset.for_create(:create, attrs)
           |> Ash.create(authorize?: false) do
        {:ok, media_log} ->
          if result.cover_url do
            lv = self()

            Task.start(fn ->
              case Weakty.ImageDownloader.download(result.cover_url, "media") do
                {:ok, local_path} -> send(lv, {:quick_cover_downloaded, {media_log.id, local_path}})
                _ -> :ok
              end
            end)
          end

          added = [%{title: result.title, creator: creator} | socket.assigns.quick_added] |> Enum.take(5)
          {:noreply, assign(socket, quick_search_results: [], quick_search_query: "", quick_added: added)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to add album")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:quick_cover_downloaded, {id, local_path}}, socket) do
    case Ash.get(Weakty.MediaLogs.MediaLog, id, authorize?: false) do
      {:ok, media_log} ->
        media_log
        |> Ash.Changeset.for_update(:update, %{thumbnail_url: local_path})
        |> Ash.update(authorize?: false)

      _ ->
        :ok
    end

    {:noreply, socket}
  end

  defp load_stats(socket) do
    require Ash.Query

    all_posts = Weakty.Posts.Post.list_posts!()
    posts = Enum.filter(all_posts, &(&1.post_type in [:post, :update, :page]))
    published_posts = Enum.filter(posts, &(&1.status == :published))
    draft_posts = Enum.filter(posts, &(&1.status == :draft))
    tils = Enum.filter(all_posts, &(&1.post_type == :til))
    quotes = Enum.filter(all_posts, &(&1.post_type == :quote))
    links = Ash.read!(Weakty.Links.Link)

    socket
    |> assign(:stats, %{
      total_posts: length(posts),
      published_posts: length(published_posts),
      draft_posts: length(draft_posts),
      total_links: length(links),
      total_tils: length(tils),
      total_quotes: length(quotes)
    })
  end

  defp maybe_put_date_published(attrs, year) when is_binary(year) do
    date =
      cond do
        String.match?(year, ~r/^\d{4}-\d{2}-\d{2}$/) -> Date.from_iso8601!(year)
        String.match?(year, ~r/^\d{4}-\d{2}$/) -> Date.from_iso8601!("#{year}-01")
        String.match?(year, ~r/^\d{4}$/) -> Date.from_iso8601!("#{year}-01-01")
        true -> nil
      end

    if date, do: Map.put(attrs, :date_published, date), else: attrs
  end

  defp maybe_put_date_published(attrs, _), do: attrs
end
