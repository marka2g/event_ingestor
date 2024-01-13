defmodule EventIngestor.UserEvent do
  @enforce_keys [:id, :user_id, :action_data]
  defstruct [:id, :user_id, :action_data]
end
