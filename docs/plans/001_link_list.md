# Plan: Build Link List Feature with Ash

## Context

You're building a personal portfolio/archive site called "weakty" using Phoenix + Ash. The site currently has authentication scaffolding but no content features yet. You want to learn Ash by building a simple "link list" feature - essentially bookmarks with commentary, similar to services like Pinboard or Raindrop.

This will be your first Ash resource beyond the auth boilerplate, so this plan focuses on teaching Ash patterns through a complete CRUD implementation.

**Current State:**
- Phoenix 1.8.3 with LiveView 1.1.0
- Ash 3.0 with AshSqlite, AshAdmin, AshGraphql
- Existing domain: `Weakty.Accounts` (User, Token resources)
- Authentication via `ash_authentication_phoenix`
- DaisyUI + Tailwind v4 for styling
- Dark mode toggle already implemented in layouts
- SQLite database

**Goal:**
Build a links feature where you can:
1. Create/edit/delete links with URL, title, and commentary
2. View all your links on a dedicated page
3. Associate links with the logged-in user
4. Learn Ash resource patterns, actions, policies, and LiveView integration

---

## Implementation Plan

### Step 1: Remove Phoenix Boilerplate (Keep Dark Mode)

**Files to modify:**
- `/lib/weakty_web/controllers/page_html/home.html.heex` - Remove Phoenix marketing content
- `/lib/weakty_web/components/layouts/root.html.heex` - Keep theme toggle, clean up unnecessary markup
- `/lib/weakty_web/components/core_components.ex` - Review but keep (these are useful utilities)

**What to preserve:**
- Dark mode toggle component in `/lib/weakty_web/components/layouts.ex`
- Theme JavaScript in root.html.heex
- CSS theme definitions in `/assets/css/app.css`
- Core components (they'll be useful for building the links UI)

**Instructions for you:**
1. Open `lib/weakty_web/controllers/page_html/home.html.heex`
2. Replace the Phoenix marketing content with a simple welcome message
3. Optionally simplify the root layout but keep the theme toggle

### Step 2: Create the Links Domain

**New file:** `/lib/weakty/links.ex`

This will be your Ash Domain - a container for related resources.

**Pattern to follow:** Look at `/lib/weakty/accounts.ex` as your template.

**What you'll type:**
```elixir
defmodule Weakty.Links do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Weakty.Links.Link
  end
end
```

**Key concepts:**
- `use Ash.Domain` - Creates an Ash domain
- `extensions: [AshAdmin.Domain]` - Adds admin panel support
- `resources do ... end` - Registers resources in this domain
- `admin do show? true end` - Makes it visible in the /admin panel

### Step 3: Create the Link Resource

**New file:** `/lib/weakty/links/link.ex`

This is the core Ash resource - it defines your data model, actions, and business logic.

**What you'll type:**
```elixir
defmodule Weakty.Links.Link do
  use Ash.Resource,
    domain: Weakty.Links,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshAdmin.Resource]

  sqlite do
    table "links"
    repo Weakty.Repo
  end

  admin do
    show? true
  end

  attributes do
    uuid_primary_key :id

    attribute :url, :string do
      allow_nil? false
      public? true
    end

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :commentary, :string do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Weakty.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:url, :title, :commentary, :user_id]
    end

    update :update do
      accept [:url, :title, :commentary]
    end
  end

  code_interface do
    define :list_links, action: :read
    define :get_link, action: :read, get?: true
    define :create_link, action: :create
    define :update_link, action: :update
    define :delete_link, action: :destroy
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end
end
```

**Key Ash concepts explained:**

1. **`use Ash.Resource`** - Makes this module an Ash resource
   - `domain:` - Associates it with the Links domain
   - `data_layer:` - Uses SQLite for persistence
   - `extensions:` - Adds admin panel UI

2. **`sqlite do ... end`** - Data layer configuration
   - `table "links"` - Database table name
   - `repo Weakty.Repo` - Uses your app's Ecto repo

3. **`attributes do ... end`** - Define your data fields
   - `uuid_primary_key :id` - Auto-generated UUID (Ash convention)
   - `attribute :url, :string` - Define fields with types
   - `allow_nil? false` - Validation (required field)
   - `public? true` - Allows external access (important for forms/APIs)
   - `timestamps()` - Adds inserted_at/updated_at

4. **`relationships do ... end`** - Define associations
   - `belongs_to :user` - Each link belongs to a user
   - `attribute_writable? true` - Allows setting user_id on create

5. **`actions do ... end`** - Define what you can do with links
   - `defaults [:read, :destroy]` - Use Ash's built-in read/destroy
   - `create :create` - Custom create action
   - `accept [...]` - Which fields can be set in this action
   - `:read` returns lists, `:destroy` deletes records

6. **`code_interface do ... end`** - Elixir functions for your actions
   - `define :list_links, action: :read` - Creates `Weakty.Links.Link.list_links()`
   - `get?: true` - Makes it return a single record instead of list
   - These are the functions you'll call in your controllers/LiveViews

7. **`policies do ... end`** - Authorization rules
   - `policy always() do authorize_if always() end` - Allow everything (we'll restrict this later)
   - Later you'll add: "users can only see their own links"

### Step 4: Update the User Resource

**File to modify:** `/lib/weakty/accounts/user.ex`

Add the inverse relationship so users know about their links.

**What to add in the `relationships do` block:**
```elixir
has_many :links, Weakty.Links.Link do
  destination_attribute :user_id
end
```

**Why:** This creates a `user.links` association for loading all links for a user.

### Step 5: Register Links Domain in Config

**File to modify:** `/config/config.exs`

Find the line with `ash_domains:` and update it:

```elixir
config :weakty,
  ash_domains: [Weakty.Accounts, Weakty.Links]
```

**Why:** Ash needs to know about your domain for code generation, admin panel, GraphQL, etc.

### Step 6: Generate and Run Migration

**Commands you'll run:**

```bash
# Generate migration from your Ash resource
mix ash_sqlite.generate_migrations --name add_links

# Review the generated migration in priv/repo/migrations/

# Run the migration
mix ecto.migrate
```

**What happens:**
- Ash reads your Link resource definition
- Generates a migration to create the `links` table
- Creates columns for: id, url, title, commentary, user_id, inserted_at, updated_at
- Adds foreign key constraint to users table

**Review the migration** - Ash generates good migrations but you should understand what's happening.

### Step 7: Create a LiveView for Links

**New file:** `/lib/weakty_web/live/link_live/index.ex`

This will be your links list page with CRUD operations.

**What you'll type:**
```elixir
defmodule WeaktyWeb.LinkLive.Index do
  use WeaktyWeb, :live_view
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_user] do
      links = 
        Weakty.Links.Link
        |> Ash.Query.filter(user_id == ^socket.assigns.current_user.id)
        |> Ash.read!()

      {:ok, assign(socket, links: links)}
    else
      {:ok, redirect(socket, to: "/sign-in")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl px-4 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold">My Links</h1>
        <button 
          phx-click="new_link" 
          class="btn btn-primary mt-4"
        >
          Add New Link
        </button>
      </div>

      <div class="space-y-4">
        <%= for link <- @links do %>
          <div class="card bg-base-200 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">
                <a href={link.url} target="_blank" class="link">
                  <%= link.title %>
                </a>
              </h2>
              <%= if link.commentary do %>
                <p><%= link.commentary %></p>
              <% end %>
              <div class="card-actions justify-end">
                <button 
                  phx-click="edit" 
                  phx-value-id={link.id}
                  class="btn btn-sm btn-ghost"
                >
                  Edit
                </button>
                <button 
                  phx-click="delete" 
                  phx-value-id={link.id}
                  data-confirm="Are you sure?"
                  class="btn btn-sm btn-error"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    link = Ash.get!(Weakty.Links.Link, id)
    Ash.destroy!(link)
    
    links = 
      Weakty.Links.Link
      |> Ash.Query.filter(user_id == ^socket.assigns.current_user.id)
      |> Ash.read!()

    {:noreply, assign(socket, links: links)}
  end

  def handle_event("new_link", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/links/new")}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/links/#{id}/edit")}
  end
end
```

**Key LiveView + Ash concepts:**

1. **`mount/3`** - Initialize the LiveView
   - Check authentication via `socket.assigns.current_user`
   - Use `Ash.Query.filter/2` to get only the current user's links
   - `Ash.read!/1` executes the query

2. **`render/1`** - HEEx template
   - Uses DaisyUI classes (card, btn, etc.)
   - `phx-click` - LiveView event handlers
   - `phx-value-id` - Pass data to event handlers

3. **`handle_event/3`** - Handle user interactions
   - `"delete"` - Uses `Ash.get!/2` then `Ash.destroy!/1`
   - Navigation with `push_navigate/2`

### Step 8: Create Form LiveView

**New file:** `/lib/weakty_web/live/link_live/form.ex`

This handles both new and edit forms.

**What you'll type:**
```elixir
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
```

**Key AshPhoenix.Form concepts:**

1. **`Form.for_create/3` or `Form.for_update/3`** - Create form structs
   - Wraps Ash actions in a Phoenix-compatible form
   - Handles validation and changesets

2. **`Form.validate/2`** - Real-time validation
   - Called on `phx-change` events
   - Updates form with errors

3. **`Form.submit/2`** - Execute the Ash action
   - Called on `phx-submit`
   - Returns `{:ok, record}` or `{:error, form}`

4. **Form field access** - `@form[:field_name].name` and `.value`
   - `.name` - Input name attribute (for form submission)
   - `.value` - Current field value

### Step 9: Add Routes

**File to modify:** `/lib/weakty_web/router.ex`

Find the `scope "/", WeaktyWeb do` block and add:

```elixir
live "/links", LinkLive.Index, :index
live "/links/new", LinkLive.Form, :new
live "/links/:id/edit", LinkLive.Form, :edit
```

**Add authentication requirement** - Wrap in a pipeline:

```elixir
scope "/", WeaktyWeb do
  pipe_through [:browser, :require_authenticated_user]

  live "/links", LinkLive.Index, :index
  live "/links/new", LinkLive.Form, :new
  live "/links/:id/edit", LinkLive.Form, :edit
end
```

**Note:** You may need to create the `:require_authenticated_user` plug or use the existing auth from `ash_authentication_phoenix`. Check the router for existing auth patterns.

### Step 10: Add Navigation Link

**File to modify:** `/lib/weakty_web/components/layouts/root.html.heex`

Add a navigation link to your links page (probably in a nav bar or header):

```heex
<.link navigate={~p"/links"} class="link">
  My Links
</.link>
```

### Step 11: Test in the Admin Panel

Before building the UI, test your resource:

1. Start your server: `mix phx.server`
2. Navigate to `http://localhost:4000/admin`
3. You should see "Links" in the sidebar
4. Try creating a link through the admin interface
5. Verify it appears in the database

**This validates:**
- Domain registration works
- Resource definition is correct
- Database migrations ran successfully
- Relationships are working

### Step 12: Improve Policies (Security)

**File to modify:** `/lib/weakty/links/link.ex`

Replace the permissive policy with proper authorization:

```elixir
policies do
  # Users can read their own links
  policy action_type(:read) do
    authorize_if expr(user_id == ^actor(:id))
  end

  # Users can create links for themselves
  policy action_type(:create) do
    authorize_if always()
  end

  # Users can only update/destroy their own links
  policy action_type([:update, :destroy]) do
    authorize_if expr(user_id == ^actor(:id))
  end
end
```

**Update your LiveView queries** to pass the actor:

```elixir
# In mount and handle_event
Weakty.Links.Link
|> Ash.Query.filter(user_id == ^socket.assigns.current_user.id)
|> Ash.read!(actor: socket.assigns.current_user)
```

**Key policy concepts:**
- `action_type/1` - Match actions by type (read, create, update, destroy)
- `expr/1` - Write expressions using resource attributes
- `^actor(:id)` - Reference the current user (the "actor")
- `authorize_if` - Conditions that grant access

---

## Verification Steps

After implementing, verify everything works:

1. **Authentication:**
   - [ ] Cannot access `/links` when logged out (redirects to sign-in)
   - [ ] Can access `/links` when logged in

2. **Create:**
   - [ ] Can navigate to `/links/new`
   - [ ] Form validates (required fields)
   - [ ] Can create a new link
   - [ ] Redirects to `/links` after save
   - [ ] New link appears in list

3. **Read:**
   - [ ] Can see list of your links at `/links`
   - [ ] Each link shows: title (as clickable URL), commentary
   - [ ] Links open in new tab

4. **Update:**
   - [ ] Click "Edit" navigates to `/links/:id/edit`
   - [ ] Form is pre-filled with existing data
   - [ ] Can update any field
   - [ ] Changes appear after save

5. **Delete:**
   - [ ] Click "Delete" shows confirmation
   - [ ] Confirming removes the link
   - [ ] Link disappears from list

6. **Authorization:**
   - [ ] Cannot see other users' links (test by creating another user)
   - [ ] Cannot edit/delete other users' links

7. **Admin Panel:**
   - [ ] Links appear in `/admin`
   - [ ] Can manage links through admin UI

8. **Dark Mode:**
   - [ ] Theme toggle still works
   - [ ] Links page respects theme choice

---

## Key Ash Learning Outcomes

By completing this, you'll learn:

1. **Ash Domains** - Organizational containers for resources
2. **Ash Resources** - Data modeling with attributes, relationships, actions
3. **Code Interface** - Creating Elixir functions for actions
4. **Policies** - Authorization and access control
5. **AshPhoenix.Form** - Integrating Ash with Phoenix forms and LiveView
6. **Ash.Query** - Querying and filtering data
7. **CRUD Actions** - create, read, update, destroy patterns
8. **Admin Panel** - AshAdmin for quick resource management

---

## Next Steps (After This Works)

Once you have links working, consider:

1. **Add Tags** - Create a Tag resource with many-to-many relationship
2. **Add Search** - Full-text search on title/commentary
3. **Public Links** - Toggle to make some links publicly viewable
4. **Import** - Bulk import from browser bookmarks
5. **Archive** - Soft-delete instead of destroying
6. **GraphQL** - Expose links via your GraphQL API

---

## File Structure Summary

**New files:**
- `/lib/weakty/links.ex` - Domain
- `/lib/weakty/links/link.ex` - Resource
- `/lib/weakty_web/live/link_live/index.ex` - List view
- `/lib/weakty_web/live/link_live/form.ex` - Create/edit form
- Migration: `priv/repo/migrations/TIMESTAMP_add_links.exs`

**Modified files:**
- `/lib/weakty/accounts/user.ex` - Add has_many relationship
- `/config/config.exs` - Register Links domain
- `/lib/weakty_web/router.ex` - Add routes
- `/lib/weakty_web/components/layouts/root.html.heex` - Add nav link
- `/lib/weakty_web/controllers/page_html/home.html.heex` - Clean up boilerplate

**Preserved:**
- `/lib/weakty_web/components/layouts.ex` - Dark mode toggle
