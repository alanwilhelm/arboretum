defmodule Arboretum.Examples.HundredAgentDemo do
  @moduledoc """
  Script demonstrating the 100-agent milestone.
  
  This module provides functions to create, manage, and execute batch operations
  with 100 concurrent agents, demonstrating the system's scalability.
  """
  
  require Logger
  alias Arboretum.BatchManager
  alias Arboretum.BatchResults
  
  @doc """
  Run the full demonstration:
  1. Create 100 agents
  2. Activate them all
  3. Have them all ask the same question to an LLM
  4. Store and display the results
  5. Clean up (deactivate and optionally delete agents)
  
  Usage:
  ```
  # Run in IEx
  iex> Arboretum.Examples.HundredAgentDemo.run()
  ```
  """
  def run(opts \\ []) do
    # Parse options
    count = Keyword.get(opts, :count, 100)
    prompt = Keyword.get(opts, :prompt, "What is the capital of France?")
    cleanup = Keyword.get(opts, :cleanup, true)
    
    Logger.info("Running 100-agent demonstration with #{count} agents")
    
    # Step 1: Create agents
    {:ok, batch} = create_agents(count)
    
    # Step 2: Activate agents
    {:ok, activation_status} = BatchManager.activate_agent_batch(batch.agent_ids)
    Logger.info("Activated #{activation_status.successful}/#{count} agents")
    
    # Step 3: Trigger batch query
    {:ok, query_status} = trigger_batch_query(batch.batch_id, batch.agent_ids, prompt)
    Logger.info("Queried #{query_status.successful}/#{count} agents")
    
    # Step 4: Get and display results
    :timer.sleep(1000) # Brief delay to allow processing
    results = BatchResults.get_batch_results(batch.batch_id)
    Logger.info("Got #{length(results)}/#{count} results")
    
    # Print some sample results
    display_results(results, batch.batch_id)
    
    # Step 5: Cleanup
    if cleanup do
      {:ok, deactivation_status} = BatchManager.deactivate_agent_batch(batch.agent_ids)
      Logger.info("Deactivated #{deactivation_status.successful}/#{count} agents")
      
      if Keyword.get(opts, :delete, false) do
        {:ok, deletion_status} = BatchManager.delete_agent_batch(batch.agent_ids)
        Logger.info("Deleted #{deletion_status.successful}/#{count} agents")
      end
    end
    
    {:ok, %{batch_id: batch.batch_id, count: count, results: length(results)}}
  end
  
  @doc """
  Create a batch of agents for the demo.
  """
  def create_agents(count \\ 100) do
    # Define base configuration
    base_config = %{
      name: "llm-batch-agent",
      status: "inactive",
      llm_config: %{
        api_key_env_var: "OPENAI_API_KEY",
        model: "gpt-4o",
        endpoint_url: "https://api.openai.com/v1/chat/completions"
      },
      prompts: %{default: "You are a helpful assistant."},
      abilities: ["Arboretum.Abilities.BatchQuery.handle/3"],
      responsibilities: ["batch_query:standard"],
      retry_policy: %{type: "fixed", max_retries: 3, delay_ms: 5000}
    }
    
    # Create batch
    BatchManager.create_agent_batch(base_config, count)
  end
  
  @doc """
  Trigger a batch query across all agents.
  """
  def trigger_batch_query(batch_id, agent_ids, prompt) do
    # Define payload
    payload = %{
      batch_id: batch_id,
      prompt: prompt
    }
    
    # Trigger responsibility
    BatchManager.trigger_batch_responsibility(agent_ids, "batch_query", payload)
  end
  
  @doc """
  Display results for the batch.
  """
  def display_results(results, batch_id) do
    result_count = length(results)
    
    if result_count > 0 do
      Logger.info("Sample results for batch #{batch_id}:")
      
      # Display first 3 results
      Enum.take(results, 3)
      |> Enum.each(fn result ->
        response_preview = String.slice(result.response, 0, 100)
        Logger.info("Agent #{result.agent_name}: #{response_preview}...")
      end)
      
      Logger.info("#{result_count} total results available. Access with:")
      Logger.info("BatchResults.get_batch_results(\"#{batch_id}\")")
    else
      Logger.warning("No results available for batch #{batch_id}")
    end
  end
end