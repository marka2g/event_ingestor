defmodule EventIngestor.EventIngestor do
  use GenServer
  require Logger

  alias EventIngestor.UserEvent

  # Client API

  # started without a :name option so as to be accessible by PID
  # or when resolved through the PartitionSupervisor
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def persist_event(%UserEvent{} = event) do
    event.id
    |> via_tuple()
    |> GenServer.cast({:persist_event, event})
  end

  def flush_events(partition) do
    # the `:flush_events` call is made to the process that is resolved
    # to the partition number provided.
    partition
    |> via_tuple()
    |> GenServer.call(:flush_events)
  end

  defp via_tuple(event_id_term) do
    {:via, PartitionSupervisor, {EventIngestorPartitionSupervisor, event_id_term}}
  end

  # Server API - Callbacks

  @impl true
  def init(_) do
    # set initial state of the process
    {:ok, %{count: 0, data: %{}}}
  end

  @impl true
  def handle_cast(
      {:persist_event, %UserEvent{} = event},
      %{count: count, data: data}
    ) do

    # yikes - 100_000 async_streams
    # IO.inspect(event, label: "event -> :persist_event")

    # every event that is sent to the GenServer is
    # used to update the state of the GenServer
    data = Map.update(data, event.id, 1, &(&1 + 1))

    {:noreply, %{count: count + 1, data: data}}
  end

  @impl true
  def handle_call(:flush_events, _from, %{count: count, data: data}) do
    # if a flush even occurs and there are buffered events that need
    # to be flushed, log out how much data was flushed.
    if count > 0 do
      Logger.info("#{__MODULE__}:#{inspect(self())} - #{count} events flushed")
    end

    # send the data to the calling process and reset the process state
    {:reply, data, %{count: 0, data: %{}}}
  end
end
