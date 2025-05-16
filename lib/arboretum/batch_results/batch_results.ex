defmodule Arboretum.BatchResults do
  @moduledoc """
  Context module for managing batch results in the database.
  
  This module provides functions for storing, retrieving, and analyzing 
  results from batch LLM operations.
  """
  
  import Ecto.Query
  require Logger
  
  alias Arboretum.Repo
  alias Arboretum.BatchResults.BatchResult
  
  @doc """
  Stores a new batch result in the database.
  
  ## Parameters
  
  - `attrs` - Map of attributes for the batch result
  
  ## Returns
  
  - `{:ok, %BatchResult{}}` - Successfully stored result
  - `{:error, changeset}` - Error with changeset
  
  ## Examples
  
  ```elixir
  Arboretum.BatchResults.store_result(%{
    batch_id: "batch-123",
    agent_id: agent_id,
    prompt: "What is the capital of France?",
    response: "The capital of France is Paris."
  })
  ```
  """
  def store_result(attrs) do
    %BatchResult{}
    |> BatchResult.changeset(attrs)
    |> Repo.insert()
  end
  
  @doc """
  Gets all results for a specific batch.
  
  ## Parameters
  
  - `batch_id` - ID of the batch
  - `opts` - Options:
    - `:limit` - Maximum number of results to return
    - `:order_by` - Field to order by (:agent_index, :inserted_at)
    - `:processed` - Filter by processed status (true, false, nil for all)
  
  ## Returns
  
  - List of %BatchResult{} structs
  
  ## Examples
  
  ```elixir
  # Get all results for batch-123
  Arboretum.BatchResults.get_batch_results("batch-123")
  
  # Get only unprocessed results, ordered by agent_index
  Arboretum.BatchResults.get_batch_results("batch-123", 
    processed: false, order_by: :agent_index)
  ```
  """
  def get_batch_results(batch_id, opts \\ []) do
    limit = Keyword.get(opts, :limit)
    order_by = Keyword.get(opts, :order_by, :agent_index)
    processed = Keyword.get(opts, :processed)
    
    BatchResult
    |> where([r], r.batch_id == ^batch_id)
    |> filter_by_processed(processed)
    |> order_by_field(order_by)
    |> limit_query(limit)
    |> Repo.all()
  end
  
  @doc """
  Gets a batch result by ID.
  
  ## Parameters
  
  - `id` - ID of the batch result
  
  ## Returns
  
  - %BatchResult{} or nil
  """
  def get_result(id) do
    Repo.get(BatchResult, id)
  end
  
  @doc """
  Gets a summary of all available batches.
  
  ## Returns
  
  - List of maps with :batch_id, :count, and :latest_timestamp
  """
  def get_batches_summary do
    query = from r in BatchResult,
            group_by: r.batch_id,
            select: %{
              batch_id: r.batch_id,
              count: count(r.id),
              latest_timestamp: max(r.inserted_at)
            },
            order_by: [desc: max(r.inserted_at)]
            
    Repo.all(query)
  end
  
  @doc """
  Marks a batch result as processed.
  
  ## Parameters
  
  - `result` - The BatchResult to update
  - `metadata` - Optional metadata to add (merged with existing)
  
  ## Returns
  
  - `{:ok, %BatchResult{}}` - Successfully updated
  - `{:error, changeset}` - Error
  """
  def mark_processed(result, metadata \\ %{}) do
    new_metadata = Map.merge(result.metadata || %{}, metadata)
    
    result
    |> BatchResult.changeset(%{processed: true, metadata: new_metadata})
    |> Repo.update()
  end
  
  @doc """
  Marks all results in a batch as processed.
  
  ## Parameters
  
  - `batch_id` - The batch ID
  - `metadata` - Optional metadata to add to all results
  
  ## Returns
  
  - `{:ok, count}` - Number of updated records
  - `{:error, reason}` - Error
  """
  def mark_batch_processed(batch_id, _metadata \\ %{}) do
    # Get all unprocessed batch results
    results = 
      BatchResult
      |> where([r], r.batch_id == ^batch_id and r.processed == false)
      |> Repo.all()
    
    # Mark each as processed
    {processed_count, _} = 
      Enum.reduce(results, {0, []}, fn result, {count, errors} ->
        case mark_processed(result) do
          {:ok, _} -> {count + 1, errors}
          error -> {count, [error | errors]}
        end
      end)
      
    {:ok, processed_count}
  end
  
  @doc """
  Deletes all results for a batch.
  
  ## Parameters
  
  - `batch_id` - The batch ID
  
  ## Returns
  
  - `{:ok, count}` - Number of deleted records
  """
  def delete_batch_results(batch_id) do
    {count, _} = 
      BatchResult
      |> where([r], r.batch_id == ^batch_id)
      |> Repo.delete_all()
      
    {:ok, count}
  end
  
  # Private helpers
  
  defp filter_by_processed(query, nil), do: query
  defp filter_by_processed(query, processed) do
    where(query, [r], r.processed == ^processed)
  end
  
  defp order_by_field(query, :agent_index) do
    order_by(query, [r], asc: r.agent_index)
  end
  
  defp order_by_field(query, :inserted_at) do
    order_by(query, [r], asc: r.inserted_at)
  end
  
  defp order_by_field(query, _), do: query
  
  defp limit_query(query, nil), do: query
  defp limit_query(query, limit) when is_integer(limit) do
    limit(query, ^limit)
  end
end