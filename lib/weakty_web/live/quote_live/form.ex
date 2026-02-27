defmodule WeaktyWeb.QuoteLive.Form do
  use WeaktyWeb, :live_view
  alias AshPhoenix.Form
  require Logger

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(params, _session, socket) do
    quote_record =
      case params["id"] do
        nil -> nil
        id ->
          Weakty.Quotes.Quote
          |> Ash.get!(id)
          |> Ash.load!(:tags)
      end

    existing_tags = if quote_record, do: Enum.map(quote_record.tags || [], & &1.name), else: []

    form =
      if quote_record do
        Form.for_update(quote_record, :update, domain: Weakty.Quotes, forms: [auto?: false])
      else
        Form.for_create(Weakty.Quotes.Quote, :create,
          domain: Weakty.Quotes,
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
     |> assign(form: form, quote: quote_record, tags: existing_tags, tag_input: "")
     |> assign(:current_path, "/admin/quotes"),
     layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen">
      <div class="flex-1 max-w-4xl mx-auto px-8 py-8">
        <div class="flex items-center gap-4 mb-8">
          <.link navigate={~p"/admin/quotes"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="w-4 h-4" />
            Quotes
          </.link>
          <div class="text-sm text-base-content/70">
            <%= if @quote, do: "Editing", else: "New quote" %>
          </div>
          <div class="flex-1" />
          <button type="submit" form="quote-form" class="btn btn-primary btn-sm">
            <%= if @quote, do: "Update", else: "Create" %>
          </button>
        </div>

        <.form id="quote-form" for={@form} phx-submit="save" phx-change="validate" class="space-y-6">
          <div class="form-control">
            <label class="label mb-1">
              <span class="label-text text-sm font-semibold">Quote</span>
            </label>
            <textarea
              name={@form[:body].name}
              class="textarea textarea-bordered w-full min-h-[160px] text-lg leading-relaxed"
              placeholder="The quote text..."
              required
            ><%= @form[:body].value %></textarea>
          </div>
        </.form>
      </div>

      <div class="w-80 border-l border-base-300 bg-base-100 p-6 overflow-y-auto max-h-screen sticky top-0">
        <h2 class="text-xl font-bold mb-6">Details</h2>
        <div class="space-y-4">
          <div class="form-control">
            <label class="label mb-1">
              <span class="label-text text-sm font-semibold">Attribution</span>
            </label>
            <input
              type="text"
              form="quote-form"
              name={@form[:attribution].name}
              value={@form[:attribution].value}
              class="input input-bordered input-sm w-full"
              placeholder="Who said it"
            />
          </div>

          <div class="form-control">
            <label class="label mb-1">
              <span class="label-text text-sm font-semibold">Source URL</span>
            </label>
            <input
              type="url"
              form="quote-form"
              name={@form[:attribution_url].name}
              value={@form[:attribution_url].value}
              class="input input-bordered input-sm w-full"
              placeholder="https://..."
            />
          </div>

          <div class="form-control">
            <label class="label mb-1">
              <span class="label-text text-sm font-semibold">Tags</span>
            </label>
            <%= if length(@tags) > 0 do %>
              <div class="flex flex-wrap gap-1 mb-2">
                <%= for tag <- @tags do %>
                  <div class="badge badge-sm gap-1">
                    <%= tag %>
                    <button type="button" phx-click="remove_tag" phx-value-tag={tag} class="btn btn-xs btn-circle btn-ghost">✕</button>
                  </div>
                <% end %>
              </div>
            <% end %>
            <form phx-submit="add_tag" phx-change="update_tag_input" class="join w-full">
              <input type="text" name="tag_input" value={@tag_input} placeholder="Add a tag" class="input input-bordered input-sm join-item flex-1 text-sm" />
              <button type="submit" class="btn btn-sm btn-ghost join-item">Add</button>
            </form>
          </div>

          <div class="divider"></div>

          <.input field={@form[:public]} type="checkbox" label="Public" form="quote-form" />

          <%= if @quote do %>
            <div class="divider"></div>
            <button
              type="button"
              phx-click="delete"
              data-confirm="Delete this quote?"
              class="btn btn-error btn-sm w-full"
            >
              Delete
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = Form.validate(socket.assigns.form, params, errors: true)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("update_tag_input", %{"tag_input" => value}, socket) do
    {:noreply, assign(socket, tag_input: value)}
  end

  def handle_event("add_tag", %{"tag_input" => value}, socket) do
    tag = String.trim(value)
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
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, q} ->
        handle_tag_update(q, socket.assigns.tags)
        {:noreply,
         socket
         |> put_flash(:info, "Saved successfully.")
         |> push_navigate(to: ~p"/admin/quotes")}

      {:error, form} ->
        Logger.error("Quote save failed: #{inspect(form.source.errors)}")
        {:noreply,
         socket
         |> put_flash(:error, "Could not save.")
         |> assign(form: to_form(form))}
    end
  end

  def handle_event("delete", _params, socket) do
    case Ash.destroy(socket.assigns.quote) do
      :ok -> {:noreply, push_navigate(socket, to: ~p"/admin/quotes")}
      {:ok, _} -> {:noreply, push_navigate(socket, to: ~p"/admin/quotes")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to delete")}
    end
  end

  defp handle_tag_update(quote_record, tags) do
    Weakty.Tags.TagManager.apply_tags(
      quote_record, :quote, tags,
      Weakty.Quotes.QuoteTag, :quote_id
    )
  end
end
