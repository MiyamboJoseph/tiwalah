defmodule App.UmmahApi.PassageCache do
  @moduledoc false
  use GenServer

  @ttl_seconds 21_600

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def fetch(key, fetcher), do: GenServer.call(__MODULE__, {:fetch, key, fetcher}, 10_000)

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:fetch, key, fetcher}, _from, state) do
    now = System.system_time(:second)

    case Map.get(state, key) do
      {expires_at, value} when expires_at > now ->
        {:reply, {:ok, value}, state}

      _ ->
        case fetcher.() do
          {:ok, value} -> {:reply, {:ok, value}, Map.put(state, key, {now + @ttl_seconds, value})}
          error -> {:reply, error, state}
        end
    end
  end
end
