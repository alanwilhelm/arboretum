defmodule Arboretum.BatchResults do
  @moduledoc """
  Manages batch results storage and retrieval.
  
  In a full implementation, this would use a database table to store results.
  For now, it uses an in-memory ETS table for demonstration purposes.
  """
  
  require Logger
  use GenServer
  
  # Client API
  
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Store a batch query result.
  
  ## Parameters
  
  - `result` - A map containing batch query result:
    - `batch_id` - Batch identifier
    - `agent_id` - Agent ID
    - `agent_name` - Agent name
    - `agent_index` - Agent index in the batch
    - `prompt` - Query prompt
    - `response` - LLM response text
    - `timestamp` - When the query was made
    
  ## Returns
  
  - `:ok` - Result stored successfully
  """
  def store_result(result) do
    GenServer.cast(__MODULE__, {:store_result, result})
  end
  
  @doc """
  Get all results for a specific batch.
  
  ## Parameters
  
  - `batch_id` - Batch identifier
  
  ## Returns
  
  - `[result]` - List of result maps
  """
  def get_batch_results(batch_id) do
    GenServer.call(__MODULE__, {:get_batch_results, batch_id})
  end
  
  @doc """
  Get a summary of all available batches.
  
  ## Returns
  
  - `[%{batch_id: String.t(), count: integer(), timestamp: DateTime.t()}]` - List of batch summaries
  """
  def get_batches_summary do
    GenServer.call(__MODULE__, :get_batches_summary)
  end
  
  @doc """
  Clear all results for a specific batch.
  
  ## Parameters
  
  - `batch_id` - Batch identifier
  
  ## Returns
  
  - `:ok` - Batch cleared
  """
  def clear_batch(batch_id) do
    GenServer.cast(__MODULE__, {:clear_batch, batch_id})
  end
  
  @doc """
  Clear all batch results.
  
  ## Returns
  
  - `:ok` - All batches cleared
  """
  def clear_all do
    GenServer.cast(__MODULE__, :clear_all)
  end
  
  # Server Callbacks
  
  @impl true
  def init(:ok) do
    # Create ETS table for storing results
    table = :ets.new(:batch_results, [:set, :protected, :named_table])
    {:ok, %{table: table}}
  end
  
  @impl true
  def handle_cast({:store_result, result}, state) do
    # Validate result has required fields
    if Map.has_key?(result, :batch_id) && Map.has_key?(result, :agent_id) && Map.has_key?(result, :response) do
      # Store result in ETS table
      key = {result.batch_id, result.agent_id}
      :ets.insert(state.table, {key, result})
      Logger.info("Stored result for batch #{result.batch_id}, agent #{result.agent_id}")
    else
      Logger.warn("Invalid result format: #{inspect(result)}")
    end
    
    {:noreply, state}
  end
  
  @impl true
  def handle_cast({:clear_batch, batch_id}, state) do
    # Delete all entries for this batch
    :ets.match_delete(state.table, {{batch_id, :_}, :_})
    Logger.info("Cleared results for batch #{batch_id}")
    
    {:noreply, state}
  end
  
  @impl true
  def handle_cast(:clear_all, state) do
    # Delete all entries
    :ets.delete_all_objects(state.table)
    Logger.info("Cleared all batch results")
    
    {:noreply, state}
  end
  
  @impl true
  def handle_call({:get_batch_results, batch_id}, _from, state) do
    # Collect all results for this batch
    results = 
      :ets.match_object(state.table, {{batch_id, :_}, :_})
      |> Enum.map(fn {{^batch_id, _agent_id}, result} -> result end)
      # Sort by agent_index
      |> Enum.sort_by(fn result -> Map.get(result, :agent_index, 0) end)
    
    {:reply, results, state}
  end
  
  @impl true
  def handle_call(:get_batches_summary, _from, state) do
    # Group by batch_id
    batch_map = 
      :ets.tab2list(state.table)
      |> Enum.map(fn {{batch_id, _agent_id}, result} -> {batch_id, result} end)
      |> Enum.group_by(fn {batch_id, _result} -> batch_id end)
    
    # Create summary for each batch
    summaries = 
      Enum.map(batch_map, fn {batch_id, results} ->
        # Find most recent timestamp
        timestamps = 
          Enum.map(results, fn {_batch_id, result} -> Map.get(result, :timestamp) end)
          |> Enum.filter(&(&1 != nil))
        
        latest_timestamp = 
          if Enum.empty?(timestamps), do: nil, else: Enum.max(timestamps)
        
        %{
          batch_id: batch_id,
          count: length(results),
          timestamp: latest_timestamp
        }
      end)
      # Sort by timestamp (newest first)
      |> Enum.sort_by(fn %{timestamp: ts} -> if ts, do: ts, else: DateTime.from_unix(0) end, {:desc, DateTime})
    
    {:reply, summaries, state}
  end
end