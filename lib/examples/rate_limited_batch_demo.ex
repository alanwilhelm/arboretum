defmodule Arboretum.Examples.RateLimitedBatchDemo do
  @moduledoc """
  A simple example demonstrating the use of rate limiting with BatchManager.
  
  This module shows how to create and run a rate-limited batch of agents
  that query an LLM.
  
  Usage:
  ```elixir
  # Run with default settings (20 agents)
  Arboretum.Examples.RateLimitedBatchDemo.run()
  
  # Run with custom settings
  Arboretum.Examples.RateLimitedBatchDemo.run(%{
    count: 50,
    prompt: "Explain quantum computing in simple terms.",
    model: "gpt-4"
  })
  ```
  """
  
  require Logger
  alias Arboretum.BatchManager
  alias Arboretum.BatchResults
  
  @doc """
  Runs the demo with the given options.
  
  ## Parameters
  
  - `opts` - Options for the demo:
    - `count` - Number of agents to create (default: 20)
    - `prompt` - Prompt to send to the LLM (default: "What is the meaning of life?")
    - `provider` - LLM provider to use (default: "simulated")
    - `model` - LLM model to use (default depends on provider)
    - `batch_id` - Optional custom batch ID
    
  ## Returns
  
  - `{:ok, %{batch_id: String.t(), agent_ids: [String.t()]}}` - Success
  - `{:error, reason}` - Error
  """
  def run(opts \\ %{}) do
    # Merge with defaults
    opts = Map.merge(
      %{
        count: 20,
        prompt: "What is the meaning of life?",
        provider: "simulated"
      },
      opts
    )
    
    # Create a batch ID
    batch_id = Map.get(opts, :batch_id, "rate-limited-demo-#{UUID.uuid4()}")
    
    # Configure the LLM based on provider
    {provider, model} = get_provider_and_model(opts)
    
    # Base configuration for agents
    base_config = %{
      name: "rate-limited-agent",
      status: "inactive",
      llm_config: %{
        "provider" => provider,
        "model" => model,
        "api_key_env_var" => get_api_key_env_var(provider)
      },
      abilities: ["Arboretum.Abilities.BatchQuery"],
      responsibilities: ["batch_query:standard"],
      prompts: %{"default" => "You are a helpful assistant."},
      retry_policy: %{"type" => "fixed", "max_retries" => 3, "delay_ms" => 5000}
    }
    
    with {:ok, %{batch_id: ^batch_id, agent_ids: agent_ids}} <- 
           BatchManager.create_agent_batch(base_config, opts.count, batch_id),
         
         # Activate the agents
         {:ok, _} <- BatchManager.activate_agent_batch(agent_ids),
         
         # Trigger the batch query with rate limiting
         {:ok, trigger_result} <- BatchManager.trigger_batch_responsibility(
           agent_ids,
           "batch_query:standard",
           %{
             batch_id: batch_id,
             prompt: opts.prompt,
             rate_limiting: %{
               enabled: true,
               max_wait_ms: 120_000,  # 2 minutes max wait
               backoff_factor: 1.5    # Exponential backoff
             }
           }
         ) do
      
      # Log the results
      Logger.info("Batch query triggered with rate limiting:")
      Logger.info("  Successful: #{trigger_result.successful}")
      Logger.info("  Failed: #{trigger_result.failed}")
      Logger.info("  Rate limited: #{trigger_result.rate_limited}")
      
      # Return batch info
      {:ok, %{batch_id: batch_id, agent_ids: agent_ids, trigger_result: trigger_result}}
    else
      {:error, reason} ->
        Logger.error("Failed to run rate-limited batch demo: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Gets the batch results for a specific batch.
  
  ## Parameters
  
  - `batch_id` - The batch ID to get results for
  
  ## Returns
  
  - `{:ok, [BatchResult.t()]}` - Success
  - `{:error, reason}` - Error
  """
  def get_results(batch_id) do
    BatchResults.list_batch_results(%{batch_id: batch_id})
  end
  
  # Helper to get provider and model
  defp get_provider_and_model(opts) do
    provider = String.downcase(opts.provider || "simulated")
    
    model = opts[:model] || case provider do
      "openai" -> "gpt-4o"
      "anthropic" -> "claude-3-opus-20240229"
      "simulated" -> "simulated-model"
      _ -> "gpt-4o"  # Default to OpenAI
    end
    
    {provider, model}
  end
  
  # Helper to get the environment variable for the API key
  defp get_api_key_env_var(provider) do
    case provider do
      "openai" -> "OPENAI_API_KEY"
      "anthropic" -> "ANTHROPIC_API_KEY"
      _ -> nil
    end
  end
end