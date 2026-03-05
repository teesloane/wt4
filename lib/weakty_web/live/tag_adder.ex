defmodule WeaktyWeb.TagAdder do
  use WeaktyWeb, :live_component
  import WeaktyWeb.FormHelpers

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       tag_input: "",
       tag_suggestions: [],
       all_tags: Weakty.Tags.Tag.list_tags!() |> Enum.map(& &1.name)
     )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, :tags, assigns.tags)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class={[
        "flex flex-wrap gap-1.5 items-center px-2 py-1.5 min-h-10 border border-base-300 bg-base-100 focus-within:border-primary cursor-text",
        if(@tag_suggestions == [], do: "rounded-lg", else: "rounded-t-lg")
      ]}>
        <span :for={tag <- @tags} class="badge badge-sm gap-1 flex-shrink-0">
          <%= tag %>
          <button
            type="button"
            phx-click="remove_tag"
            phx-value-tag={tag}
            phx-target={@myself}
            class="leading-none opacity-50 hover:opacity-100"
          >✕</button>
        </span>
        <form phx-submit="add_tag" phx-target={@myself} class="flex-1 min-w-[80px]">
          <input
            type="text"
            name="tag_input"
            value={@tag_input}
            phx-change="update_tag_input"
            phx-debounce="100"
            phx-target={@myself}
            placeholder={if @tags == [], do: "Add tags...", else: ""}
            autocomplete="off"
            class="w-full outline-none bg-transparent text-sm py-0.5"
          />
        </form>
      </div>
      <div
        :if={length(@tag_suggestions) > 0}
        class="w-full bg-base-100 border border-base-300 border-t-0 rounded-b-lg max-h-40 overflow-y-auto"
      >
        <button
          :for={s <- @tag_suggestions}
          type="button"
          phx-click="select_tag"
          phx-value-tag={s}
          phx-target={@myself}
          class="w-full text-left px-3 py-1.5 text-sm hover:bg-base-200"
        >
          <%= s %>
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("update_tag_input", %{"tag_input" => value}, socket) do
    suggestions = suggest_tags(value, socket.assigns.all_tags, socket.assigns.tags)
    {:noreply, assign(socket, tag_input: value, tag_suggestions: suggestions)}
  end

  def handle_event("add_tag", %{"tag_input" => value}, socket) do
    tag = String.trim(value)
    if tag != "" and tag not in socket.assigns.tags do
      updated = socket.assigns.tags ++ [tag]
      send(self(), {:tag_changed, updated})
      {:noreply, assign(socket, tags: updated, tag_input: "", tag_suggestions: [])}
    else
      {:noreply, assign(socket, tag_input: "", tag_suggestions: [])}
    end
  end

  def handle_event("add_tag", _params, socket), do: {:noreply, socket}

  def handle_event("select_tag", %{"tag" => tag}, socket) do
    if tag not in socket.assigns.tags do
      updated = socket.assigns.tags ++ [tag]
      send(self(), {:tag_changed, updated})
      {:noreply, assign(socket, tags: updated, tag_input: "", tag_suggestions: [])}
    else
      {:noreply, assign(socket, tag_input: "", tag_suggestions: [])}
    end
  end

  def handle_event("remove_tag", %{"tag" => tag}, socket) do
    updated = List.delete(socket.assigns.tags, tag)
    send(self(), {:tag_changed, updated})
    {:noreply, assign(socket, tags: updated)}
  end
end
