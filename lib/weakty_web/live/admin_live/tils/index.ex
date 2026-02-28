defmodule WeaktyWeb.AdminLive.Tils.Index do
  use WeaktyWeb, :live_view

  import WeaktyWeb.AdminComponents
  require Ash.Query

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "TILs")
     |> assign(:current_path, "/admin/til")
     |> load_tils(), layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    post = Ash.get!(Weakty.Posts.Post, id)

    case Ash.destroy(post) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "TIL deleted")
         |> load_tils()}

      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "TIL deleted")
         |> load_tils()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete TIL")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_header title="TILs" subtitle={"#{length(@tils)} TIL#{if length(@tils) != 1, do: "s"}"}>
      <:actions>
        <.link navigate="/admin/til/new" class="btn btn-primary">
          <.icon name="hero-plus" class="w-4 h-4" />
          New TIL
        </.link>
      </:actions>
    </.admin_header>

    <div class="p-8">
      <%= if @tils == [] do %>
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body items-center text-center">
            <.icon name="hero-light-bulb" class="w-16 h-16 text-base-content/30" />
            <h2 class="card-title">No TILs yet</h2>
            <p class="text-base-content/70">Start logging things you've learned</p>
            <.link navigate="/admin/til/new" class="btn btn-primary mt-4">
              <.icon name="hero-plus" class="w-4 h-4" />
              Add TIL
            </.link>
          </div>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Title</th>
                <th>Tags</th>
                <th>Public</th>
                <th>Published</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for til <- @tils do %>
                <tr class="hover cursor-pointer" phx-click={JS.navigate(~p"/admin/til/#{til.id}/edit")}>
                  <td class="font-medium"><%= til.title %></td>
                  <td>
                    <%= if til.tags && til.tags != [] do %>
                      <div class="flex gap-1 flex-wrap">
                        <%= for tag <- Enum.take(til.tags, 3) do %>
                          <span class="badge badge-sm"><%= tag.name %></span>
                        <% end %>
                        <%= if length(til.tags) > 3 do %>
                          <span class="badge badge-sm badge-ghost">+<%= length(til.tags) - 3 %></span>
                        <% end %>
                      </div>
                    <% else %>
                      <span class="text-base-content/50">-</span>
                    <% end %>
                  </td>
                  <td>
                    <span class={["badge badge-sm", if(til.public, do: "badge-success", else: "badge-ghost")]}>
                      <%= if til.public, do: "public", else: "draft" %>
                    </span>
                  </td>
                  <td class="text-sm text-base-content/70">
                    <%= if til.published_at, do: Calendar.strftime(til.published_at, "%b %d, %Y"), else: "-" %>
                  </td>
                  <td onclick="event.stopPropagation()">
                    <div class="flex gap-2">
                      <.link navigate={~p"/admin/til/#{til.id}/edit"} class="btn btn-ghost btn-xs" title="Edit">
                        <.icon name="hero-pencil" class="w-4 h-4" />
                      </.link>
                      <button
                        phx-click="delete"
                        phx-value-id={til.id}
                        data-confirm="Delete this TIL?"
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

  defp load_tils(socket) do
    tils =
      Weakty.Posts.Post
      |> Ash.Query.filter(post_type == :til)
      |> Ash.Query.sort(published_at: :desc)
      |> Ash.read!(load: [:tags])
    assign(socket, :tils, tils)
  end
end
