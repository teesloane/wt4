defmodule Weakty.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WeaktyWeb.Telemetry,
      Weakty.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:weakty, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:weakty, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Weakty.PubSub},
      # Start a worker by calling: Weakty.Worker.start_link(arg)
      # {Weakty.Worker, arg},
      # Start to serve requests, typically the last entry
      WeaktyWeb.Endpoint,
      {Absinthe.Subscription, WeaktyWeb.Endpoint},
      AshGraphql.Subscription.Batcher,
      {AshAuthentication.Supervisor, [otp_app: :weakty]},
      {Oban, Application.fetch_env!(:weakty, Oban)}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Weakty.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WeaktyWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
