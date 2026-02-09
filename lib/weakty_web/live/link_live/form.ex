
defmodule WeaktyWeb.LinkLive.Form do
  use WeaktyWeb, :live_view
  alias AshPhoenix.Form

  @impl true
  def mount(params, _session, socket) do
    if socket.assigns[:current_user] do
      link =
        case params["id"] do
          nil -> nil
          id -> Ash.get!(Weakty.Links.Link, id)
        end

      form =
        if link do
          Form.for_update(link, :update, domain: Weakty.Links)
        else
          Form.for_create(Weakty.Links.Link, :create,
            domain: Weakty.Links,
            prepare_source: fn changeset ->
              Ash.Changeset.set_context(changeset, %{user_id: socket.assigns.current_user.id})
            end
          )
        end
        |> Form.validate(%{})
        |> to_form()

      {:ok, assign(socket, form: form, link: link)}
    else
      {:ok, redirect(socket, to: "/sign-in")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">
        <%= if @link, do: "Edit Link", else: "New Link" %>
      </h1>

      <.form
        for={@form}
        phx-submit="save"
        phx-change="validate"
        class="space-y-4"
      >
        <div class="form-control">
          <label class="label">
            <span class="label-text">URL</span>
          </label>
          <input
            type="url"
            name={@form[:url].name}
            value={@form[:url].value}
            class="input input-bordered w-full"
            required
          />
        </div>

        <div class="form-control">
          <label class="label">
            <span class="label-text">Title</span>
          </label>
          <input
            type="text"
            name={@form[:title].name}
            value={@form[:title].value}
            class="input input-bordered w-full"
            required
          />
        </div>

        <div class="form-control">
          <label class="label">
            <span class="label-text">Commentary</span>
          </label>
          <textarea
            name={@form[:commentary].name}
            class="textarea textarea-bordered w-full h-32"
          ><%= @form[:commentary].value %></textarea>
        </div>

        <input
          type="hidden"
          name={@form[:user_id].name}
          value={@current_user.id}
        />

        <div class="flex gap-2">
          <button type="submit" class="btn btn-primary">
            Save
          </button>
          <.link navigate={~p"/links"} class="btn btn-ghost">
            Cancel
          </.link>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = Form.validate(socket.assigns.form, params, errors: true)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _link} ->
        {:noreply, push_navigate(socket, to: ~p"/links")}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end
end
