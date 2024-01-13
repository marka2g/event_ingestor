defmodule EventIngestor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    partitions = 3
    init_args = [flush_interval: 1_000]
    children = [
      EventIngestorWeb.Telemetry,
      EventIngestor.Repo,
      {DNSCluster, query: Application.get_env(:event_ingestor, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: EventIngestor.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: EventIngestor.Finch},
      # Start a worker by calling: EventIngestor.Worker.start_link(arg)
      # {EventIngestor.Worker, arg},
      # Start to serve requests, typically the last entry
      EventIngestorWeb.Endpoint,
      {
        PartitionSupervisor,
        child_spec: EventIngestor.EventIngestor.child_spec(init_args),
        name: EventIngestorPartitionSupervisor,
        partitions: partitions
      },
      {
        PartitionSupervisor,
        child_spec: EventIngestor.EventFlusher.child_spec(init_args),
        name: EventFlusherPartitionSupervisor,
        partitions: partitions,
        with_arguments: fn [opts], partition ->
          [Keyword.put(opts, :partition, partition)]
        end
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EventIngestor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EventIngestorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
