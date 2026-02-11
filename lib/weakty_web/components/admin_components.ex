defmodule WeaktyWeb.AdminComponents do
  use Phoenix.Component
  import WeaktyWeb.CoreComponents
  use Gettext, backend: WeaktyWeb.Gettext

  attr :path, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :current_path, :string, required: true

  def nav_item(assigns) do
    ~H"""
    <li>
      <.link
        navigate={@path}
        class={[
          if(String.starts_with?(@current_path, @path), do: "active", else: "")
        ]}
      >
        <.icon name={@icon} class="w-5 h-5" />
        <%= @label %>
      </.link>
    </li>
    """
  end

  attr :current_path, :string, required: true
  attr :class, :string, default: nil

  def admin_sidebar(assigns) do
    ~H"""
    <aside class={["w-64 bg-base-200 border-r border-base-300 flex flex-col h-screen", @class]} style="font-family: 'IBM Plex Sans', sans-serif;">
      <div class="p-6 border-b border-base-300">
        <.link navigate="/" class="text-xl font-bold">Weakty</.link>
      </div>

      <nav class="flex-1 overflow-y-auto p-4">
        <ul class="menu menu-sm gap-1 flex w-full text-[40px]">
          <.nav_item path="/admin" label="Dashboard" icon="hero-home" current_path={@current_path} />
          <.nav_item path="/admin/posts" label="Posts" icon="hero-document-text" current_path={@current_path} />
          <.nav_item path="/admin/projects" label="Projects" icon="hero-briefcase" current_path={@current_path} />
          <.nav_item path="/admin/links" label="Links" icon="hero-link" current_path={@current_path} />
          <.nav_item path="/admin/media-logs" label="Media Logs" icon="hero-book-open" current_path={@current_path} />
          <.nav_item path="/admin/tags" label="Tags" icon="hero-tag" current_path={@current_path} />
        </ul>
      </nav>

      <div class="p-4 border-t border-base-300">
        <label class="swap swap-rotate">
          <input
            type="checkbox"
            class="theme-controller"
            value="light"
            phx-hook="ThemeToggle"
            id="admin-theme-toggle"
          />
          <.icon name="hero-sun" class="swap-on w-6 h-6" />
          <.icon name="hero-moon" class="swap-off w-6 h-6" />
        </label>
      </div>
    </aside>
    """
  end

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :actions

  def admin_header(assigns) do
    ~H"""
    <header class="bg-base-100 border-b border-base-300 px-8 py-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-bold"><%= @title %></h1>
          <p :if={@subtitle} class="text-base-content/70 mt-1"><%= @subtitle %></p>
        </div>
        <div :if={@actions != []}>
          <%= render_slot(@actions) %>
        </div>
      </div>
    </header>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :class, :string, default: nil

  def stat_card(assigns) do
    ~H"""
    <div class={["stats shadow", @class]}>
      <div class="stat">
        <div class="stat-title"><%= @label %></div>
        <div class="stat-value"><%= @value %></div>
      </div>
    </div>
    """
  end

  attr :status, :atom, required: true

  def status_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-sm",
      case @status do
        :published -> "badge-success"
        :draft -> "badge-warning"
        _ -> "badge-ghost"
      end
    ]}>
      <%= @status |> to_string() |> String.capitalize() %>
    </span>
    """
  end
end
