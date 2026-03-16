defmodule WeaktyWeb.AdminLive.Quotes.Index do
  use WeaktyWeb, :live_view

  import WeaktyWeb.AdminComponents
  require Ash.Query

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Quotes")
     |> assign(:current_path, "/admin/quotes")
     |> load_quotes(), layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    post = Ash.get!(Weakty.Posts.Post, id)

    case Ash.destroy(post) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Quote deleted")
         |> load_quotes()}

      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Quote deleted")
         |> load_quotes()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete quote")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_header
      title="Quotes"
      subtitle={"#{length(@quotes)} quote#{if length(@quotes) != 1, do: "s"}"}
    >
      <:actions>
        <.link navigate="/admin/quotes/new" class="btn btn-primary">
          <.icon name="hero-plus" class="w-4 h-4" /> New Quote
        </.link>
      </:actions>
    </.admin_header>

    <div class="p-8">
      <%= if @quotes == [] do %>
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body items-center text-center">
            <.icon name="hero-chat-bubble-left" class="w-16 h-16 text-base-content/30" />
            <h2 class="card-title">No quotes yet</h2>
            <p class="text-base-content/70">Add your first quote to get started</p>
            <.link navigate="/admin/quotes/new" class="btn btn-primary mt-4">
              <.icon name="hero-plus" class="w-4 h-4" /> Add Quote
            </.link>
          </div>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Quote</th>
                <th>Attribution</th>
                <th>Public</th>
                <th>Added</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for q <- @quotes do %>
                <tr
                  class="hover cursor-pointer"
                  phx-click={JS.navigate(~p"/admin/quotes/#{q.id}/edit")}
                >
                  <td class="max-w-sm">
                    <div class="text-sm truncate italic">"{q.markdown}"</div>
                  </td>
                  <td class="text-sm text-base-content/70">
                    {q.attribution || "-"}
                  </td>
                  <td>
                    <span class={[
                      "badge badge-sm",
                      if(q.public, do: "badge-success", else: "badge-ghost")
                    ]}>
                      {if q.public, do: "public", else: "draft"}
                    </span>
                  </td>
                  <td class="text-sm text-base-content/70">
                    {Calendar.strftime(q.inserted_at, "%b %d, %Y")}
                  </td>
                  <td onclick="event.stopPropagation()">
                    <div class="flex gap-2">
                      <.link
                        navigate={~p"/admin/quotes/#{q.id}/edit"}
                        class="btn btn-ghost btn-xs"
                        title="Edit"
                      >
                        <.icon name="hero-pencil" class="w-4 h-4" />
                      </.link>
                      <button
                        phx-click="delete"
                        phx-value-id={q.id}
                        phx-confirm="Delete this quote?"
                        class="btn btn-ghost btn-xs text-error"
                        title="Delete"
                      >
                        <.icon name="hero-trash" class="w-4 h-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  defp load_quotes(socket) do
    quotes =
      Weakty.Posts.Post
      |> Ash.Query.filter(post_type == :quote)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read!(load: [:tags])

    assign(socket, :quotes, quotes)
  end
end
