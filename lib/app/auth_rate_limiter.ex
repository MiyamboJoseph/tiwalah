defmodule App.AuthRateLimiter do
  @moduledoc false
  use GenServer

  @table __MODULE__

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def allowed?(action, identifier) do
    GenServer.call(__MODULE__, {:allowed?, action, identifier})
  end

  @impl true
  def init(:ok), do: {:ok, :ets.new(@table, [:named_table, :set, :protected])}

  @impl true
  def handle_call({:allowed?, action, identifier}, _from, table) do
    {limit, window_seconds} = limits(action)
    key = {action, String.downcase(to_string(identifier || "unknown"))}
    now = System.system_time(:second)
    timestamps = :ets.lookup(table, key) |> Enum.flat_map(fn {^key, values} -> values end)
    timestamps = Enum.filter(timestamps, &(&1 > now - window_seconds))

    if length(timestamps) < limit do
      :ets.insert(table, {key, [now | timestamps]})
      {:reply, true, table}
    else
      {:reply, false, table}
    end
  end

  defp limits(:login), do: {8, 300}
  defp limits(:registration), do: {4, 3_600}
end
