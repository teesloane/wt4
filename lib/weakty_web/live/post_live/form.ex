defmodule WeaktyWeb.PostLive.Form do
  use WeaktyWeb, :live_view
  alias AshPhoenix.Form

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(params, _session, socket) do
    post =
      case params["id"] do
        nil -> nil
        id ->
          Weakty.Posts.Post
          |> Ash.get!(id)
          |> Ash.load!(:tags)
      end

    # Extract existing tag names if editing
    existing_tags = if post, do: Enum.map(post.tags || [], & &1.name), else: []

    form =
      if post do
        Form.for_update(post, :update, domain: Weakty.Posts, forms: [auto?: false])
      else
        Form.for_create(Weakty.Posts.Post, :create,
          domain: Weakty.Posts,
          forms: [auto?: false],
          prepare_source: fn changeset ->
            changeset
            |> Ash.Changeset.set_context(%{user_id: socket.assigns.current_user.id})
            |> Ash.Changeset.force_change_attribute(:user_id, socket.assigns.current_user.id)
          end
        )
      end
      |> Form.validate(%{})
      |> to_form()

    {:ok,
     socket
     |> assign(form: form, post: post, preview: false, tags: existing_tags, tag_input: "")
     |> assign(:current_path, "/admin/posts"),
     layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl px-4 py-8">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold">
          <%= if @post, do: "Edit Post", else: "New Post" %>
        </h1>
        <button
          phx-click="toggle_preview"
          class="btn btn-ghost btn-sm"
        >
          <%= if @preview, do: "Edit", else: "Preview" %>
        </button>
      </div>

      <%= if @preview do %>
        <div class="prose prose-lg max-w-none">
          <h1><%= @form[:title].value %></h1>
          <%= if @form[:featured_image].value do %>
            <img src={@form[:featured_image].value} alt={@form[:title].value} class="w-full rounded-lg" />
          <% end %>
          <%= if @form[:excerpt].value do %>
            <p class="lead"><%= @form[:excerpt].value %></p>
          <% end %>
          <div>
            <%= raw(render_markdown(@form[:markdown].value || "")) %>
          </div>
        </div>
      <% else %>
        <.form
          for={@form}
          phx-submit="save"
          phx-change="validate"
          class="space-y-6"
        >
          <div class="form-control">
            <label class="label">
              <span class="label-text font-semibold">Title</span>
            </label>
            <input
              type="text"
              name={@form[:title].name}
              value={@form[:title].value}
              class="input input-bordered w-full text-xl"
              placeholder="Enter your post title..."
              required
            />
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text font-semibold">Slug</span>
              <span class="label-text-alt">Leave empty to auto-generate from title</span>
            </label>
            <input
              type="text"
              name={@form[:slug].name}
              value={@form[:slug].value}
              class="input input-bordered w-full"
              placeholder="url-friendly-slug"
            />
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text font-semibold">Featured Image URL</span>
            </label>
            <input
              type="url"
              name={@form[:featured_image].name}
              value={@form[:featured_image].value}
              class="input input-bordered w-full"
              placeholder="https://example.com/image.jpg"
            />
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text font-semibold">Excerpt</span>
              <span class="label-text-alt">Short summary of your post</span>
            </label>
            <textarea
              name={@form[:excerpt].name}
              class="textarea textarea-bordered w-full h-20"
              placeholder="A brief summary..."
            ><%= @form[:excerpt].value %></textarea>
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text font-semibold">Content (Markdown)</span>
            </label>
            <textarea
              name={@form[:markdown].name}
              class="textarea textarea-bordered w-full h-96 font-mono"
              placeholder="Write your post in markdown..."
              required
            ><%= @form[:markdown].value %></textarea>
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text font-semibold">Tags</span>
            </label>

            <%= if length(@tags) > 0 do %>
              <div class="flex flex-wrap gap-2 mb-2">
                <%= for tag <- @tags do %>
                  <div class="badge badge-lg gap-2">
                    <%= tag %>
                    <button
                      type="button"
                      phx-click="remove_tag"
                      phx-value-tag={tag}
                      class="btn btn-xs btn-circle btn-ghost"
                    >
                      ✕
                    </button>
                  </div>
                <% end %>
              </div>
            <% end %>

            <div class="join w-full">
              <input
                type="text"
                value={@tag_input}
                phx-change="update_tag_input"
                name="tag_input"
                placeholder="Add a tag (press Enter)"
                class="input input-bordered join-item w-full"
                phx-keydown="add_tag"
                phx-key="Enter"
              />
              <button
                type="button"
                phx-click="add_tag"
                class="btn btn-primary join-item"
              >
                Add
              </button>
            </div>
          </div>

          <div class="divider"></div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="form-control">
              <label class="label cursor-pointer">
                <span class="label-text">Featured Post</span>
                <input
                  type="checkbox"
                  name={@form[:featured].name}
                  checked={@form[:featured].value}
                  class="checkbox"
                />
              </label>
            </div>

            <div class="form-control">
              <label class="label cursor-pointer">
                <span class="label-text">Public</span>
                <input
                  type="checkbox"
                  name={@form[:public].name}
                  checked={@form[:public].value}
                  class="checkbox"
                />
              </label>
            </div>
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text font-semibold">Status</span>
            </label>
            <select
              name={@form[:status].name}
              class="select select-bordered w-full"
            >
              <option value="draft" selected={@form[:status].value == :draft || @form[:status].value == "draft"}>
                Draft
              </option>
              <option value="published" selected={@form[:status].value == :published || @form[:status].value == "published"}>
                Published
              </option>
            </select>
          </div>

          <div class="divider"></div>

          <div class="flex gap-2">
            <button type="submit" class="btn btn-primary">
              <%= if @post, do: "Update Post", else: "Create Post" %>
            </button>
            <.link navigate={~p"/posts"} class="btn btn-ghost">
              Cancel
            </.link>
          </div>
        </.form>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = Form.validate(socket.assigns.form, params, errors: true)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("toggle_preview", _params, socket) do
    {:noreply, assign(socket, preview: !socket.assigns.preview)}
  end

  def handle_event("update_tag_input", %{"tag_input" => value}, socket) do
    {:noreply, assign(socket, tag_input: value)}
  end

  def handle_event("add_tag", _params, socket) do
    tag = String.trim(socket.assigns.tag_input)

    if tag != "" and tag not in socket.assigns.tags do
      {:noreply, assign(socket, tags: socket.assigns.tags ++ [tag], tag_input: "")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_tag", %{"tag" => tag}, socket) do
    {:noreply, assign(socket, tags: List.delete(socket.assigns.tags, tag))}
  end

  def handle_event("save", %{"form" => params}, socket) do
    # First, create/update the post without tags
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, post} ->
        # Then add tags as a separate step
        if length(socket.assigns.tags) > 0 do
          tags_param = Enum.map(socket.assigns.tags, &%{name: &1})

          # Update the post with tags
          post
          |> Ash.Changeset.for_update(:update, %{})
          |> Ash.Changeset.set_argument(:tags, tags_param)
          |> Ash.update()
        end

        {:noreply, push_navigate(socket, to: ~p"/admin/posts")}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  defp render_markdown(nil), do: ""
  defp render_markdown(""), do: ""

  defp render_markdown(markdown) do
    case Earmark.as_html(markdown) do
      {:ok, html, _} -> html
      {:error, _, _} -> "<p>Error rendering markdown</p>"
    end
  end
end
