defmodule EventIngestor.EventFlusher do
  use GenServer
  require Logger

  alias EventIngestor.EventIngestor

  @moduledoc """
  A GenServer module responsible for flushing the ingested data on an interval. Functions similar to a cronjob service
  """
  # Client API

  def start_link(opts) do
    # the `EventFlusher` GenServer is started without the :name option
    # and will be accessible only by PID, or when resolved through
    # `PartitionSupervisor`. Being a backend worker process, this
    # GenServer does not have much of a client-side API so there is no
    # helper to create the `:via` tuple.
    GenServer.start_link(__MODULE__, opts)
  end

  # Server API - Callbacks
  @impl true
  # in addition to expecting the `:flush_interval` option,
  # this GenServer also now requires the `:partition` option
  # to be available in the initialization options. This will
  # be provided by `PartitionSupervisor`
  def init(opts) do
    state = %{
      flush_interval: Keyword.fetch!(opts, :flush_interval),
      partition:      Keyword.fetch!(opts, :partition)
    }

    # schedule the next cron job run using the handle_continue/2
    # callback function.
    {:ok, state, {:continue, :schedule_next_run}}
  end

  @impl true
  def handle_continue(:schedule_next_run, state) do
    # schedule for the process to receive the `:perform_cron_work`
    # message after the configured amount of time.
    Process.send_after(self(), :perform_cron_work, state.flush_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info(:perform_cron_work, state) do
    # flush the action_data that is buffered in the instance of the `EventIngestor`
    # process corresponding to the particular partition configured in the
    # instance of `EventFlusher`.
    persist_data_to_db = EventIngestor.flush_events(state.partition)

    unless map_size(persist_data_to_db) == 0 do
      Logger.info("#{__MODULE__}:#{inspect(self())} - Flushed persist_data_to_db: #{inspect(persist_data_to_db)}")
    end

    # schedule the next cron job run using the same `handle_continue/2`
    # callback as was used from `init/1`
    {:noreply, state, {:continue, :schedule_next_run}}
  end
end
