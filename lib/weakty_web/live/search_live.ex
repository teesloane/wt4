defmodule WeaktyWeb.SearchLive do
  use WeaktyWeb, :live_view

  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, open: false, query: "", results: []), layout: false}
  end

  @impl true
  def handle_event("open_search", _params, socket) do
    {:noreply, assign(socket, open: true)}
  end

  def handle_event("close_search", _params, socket) do
    {:noreply, assign(socket, open: false, query: "", results: [])}
  end

  def handle_event("search", %{"query" => query}, socket) do
    results =
      if String.length(String.trim(query)) >= 2 do
        Weakty.Content.Entity.search_entities!(query)
      else
        []
      end

    {:noreply, assign(socket, query: query, results: results)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="search-modal-container" phx-hook="SearchModal">
      <div :if={@open} class="fixed inset-0 z-[200]">
        <%!-- Backdrop --%>
        <div
          class="absolute inset-0 bg-black/60 backdrop-blur-sm"
          phx-click="close_search"
        >
        </div>

        <%!-- Modal panel --%>
        <div class="relative flex items-start justify-center pt-20 px-4">
          <div class="w-full max-w-xl bg-base-100 rounded-2xl shadow-2xl border border-base-300 overflow-hidden">
            <%!-- Search input row --%>
            <div class="flex items-center gap-3 px-4 border-b border-base-300">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="2"
                stroke="currentColor"
                class="w-5 h-5 flex-shrink-0 opacity-40"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
                />
              </svg>

              <input
                id="search-input"
                type="text"
                value={@query}
                name="query"
                phx-keyup="search"
                phx-debounce="200"
                placeholder="Search posts, projects, links, media..."
                class="flex-1 py-4 bg-transparent text-base placeholder:text-base-content/40 focus:outline-none"
                phx-mounted={JS.focus()}
                autocomplete="off"
                spellcheck="false"
              />

              <kbd class="kbd kbd-sm opacity-40">esc</kbd>
            </div>

            <%!-- Results area --%>
            <div class="max-h-80 overflow-y-auto">
              <%= if @query != "" do %>
                <%= if Enum.empty?(@results) do %>
                  <div class="px-4 py-8 text-center text-base-content/50 text-sm">
                    No results for "<%= @query %>"
                  </div>
                <% else %>
                  <%= for result <- @results do %>
                    <.link
                      navigate={"#{result.source_path}/#{result.slug}"}
                      phx-click="close_search"
                      class="flex items-center gap-4 px-4 py-3 hover:bg-base-200 transition-colors group"
                    >
                      <%!-- Thumbnail or type icon --%>
                      <div class="flex-shrink-0 w-10 h-10 rounded-lg bg-base-200 overflow-hidden flex items-center justify-center">
                        <%= if result.thumbnail_url do %>
                          <img
                            src={result.thumbnail_url}
                            class="w-full h-full object-cover"
                            alt=""
                          />
                        <% else %>
                          <span class="text-[9px] font-bold uppercase tracking-wider opacity-40">
                            <%= entity_type_abbr(result.entity_type) %>
                          </span>
                        <% end %>
                      </div>

                      <%!-- Title and type --%>
                      <div class="flex-1 min-w-0">
                        <div class="text-sm truncate">
                          <%= result.title %>
                        </div>
                        <div class="text-xs text-base-content/50 uppercase tracking-wider mt-0.5">
                          <%= entity_type_label(result.entity_type) %>
                        </div>
                      </div>

                      <%!-- Arrow --%>
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke-width="2"
                        stroke="currentColor"
                        class="w-4 h-4 opacity-0 group-hover:opacity-30 transition-opacity flex-shrink-0"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M8.25 4.5l7.5 7.5-7.5 7.5"
                        />
                      </svg>
                    </.link>
                  <% end %>
                <% end %>
              <% else %>
                <div class="px-4 py-6 text-center text-base-content/40 text-sm">
                  Start typing to search...
                </div>
              <% end %>
            </div>

            <%!-- Footer hints --%>
            <div class="flex gap-4 px-4 py-2 border-t border-base-300 text-xs text-base-content/40">
              <span class="flex items-center gap-1">
                <kbd class="kbd kbd-xs">↵</kbd> select
              </span>
              <span class="flex items-center gap-1">
                <kbd class="kbd kbd-xs">esc</kbd> close
              </span>
              <span class="ml-auto flex items-center gap-1">
                <kbd class="kbd kbd-xs">⌘K</kbd>
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp entity_type_label(:post), do: "Post"
  defp entity_type_label(:project), do: "Project"
  defp entity_type_label(:link), do: "Link"
  defp entity_type_label(:media_log), do: "Media"
  defp entity_type_label(_), do: "Entry"

  defp entity_type_abbr(:post), do: "POST"
  defp entity_type_abbr(:project), do: "PROJ"
  defp entity_type_abbr(:link), do: "LINK"
  defp entity_type_abbr(:media_log), do: "MEDIA"
  defp entity_type_abbr(_), do: "?"
end
