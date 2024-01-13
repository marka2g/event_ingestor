defmodule EventIngestor.Repo do
  use Ecto.Repo,
    otp_app: :event_ingestor,
    adapter: Ecto.Adapters.Postgres
end
