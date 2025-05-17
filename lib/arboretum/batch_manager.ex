defmodule Arboretum.BatchManager do
  @moduledoc """
  Handles the creation and management of agent batches with rate limiting.
  
  This module provides:
  - Functions for creating and managing large batches of agents
  - Support for concurrent LLM querying (100-agent milestone)
  - Integrated rate limiting to prevent overloading LLM APIs
  - Provider and model-specific rate limits
  - Configurable waiting and backoff strategies
  
  ## Rate Limiting Features
  
  The module includes:
  
  - Provider-specific rate limits (OpenAI, Anthropic, etc.)
  - Model-specific rate limits (GPT-4, Claude-3, etc.)
  - Configurable max wait times and backoff strategies
  - Automatic detection of provider/model from agent configuration
  - Support for batch operations with rate limiting
  
  ## Example: Rate Limited Batch Query
  
  ```elixir
  # Create a batch of agents
  {:ok, %{batch_id: batch_id, agent_ids: agent_ids}} = BatchManager.create_agent_batch(base_config, 100)
  
  # Activate all agents
  {:ok, _} = BatchManager.activate_agent_batch(agent_ids)
  
  # Trigger a responsibility with rate limiting
  {:ok, result} = BatchManager.trigger_batch_responsibility(
    agent_ids,
    "batch_query:standard",
    %{
      batch_id: batch_id,
      prompt: "What is the capital of France?",
      rate_limiting: %{
        enabled: true,
        max_wait_ms: 60_000,  # 1 minute maximum wait
        backoff_factor: 1.5    # Exponential backoff
      }
    }
  )
  
  # Check the results
  IO.inspect(result.successful, label: "Successful")
  IO.inspect(result.failed, label: "Failed")
  IO.inspect(result.rate_limited, label: "Rate limited")
  ```
  """
  
  require Logger
  alias Arboretum.Agents
  alias Arboretum.Agents.Agent
  
  # Rate limiting buckets for different LLM providers
  @rate_limit_buckets %{
    # Default bucket for general rate limiting
    default: {60_000, 100},  # 100 requests per minute
    
    # Provider-specific rate limits
    openai: {60_000, 90},    # 90 requests per minute (TPM)
    anthropic: {60_000, 60}, # 60 requests per minute
    simulated: {60_000, 500}, # 500 requests per minute (very high for testing)
    
    # Model-specific rate limits (can be more restrictive)
    "gpt-4": {60_000, 40},   # 40 requests per minute
    "gpt-4o": {60_000, 80},  # 80 requests per minute
    "claude-3": {60_000, 50} # 50 requests per minute
  }
  
  @doc """
  Creates a batch of agents with the same configuration but unique names.
  
  ## Parameters
  
  - `base_config` - Base configuration for the agents
  - `count` - Number of agents to create (default: 100)
  - `batch_id` - Unique identifier for this batch (default: generated UUID)
  
  ## Returns
  
  - `{:ok, %{batch_id: String.t(), agent_ids: [String.t()]}}` - Success
  - `{:error, reason}` - Error creating agents
  
  ## Examples
  
  ```elixir
  base_config = %{
    name: "batch-agent",
    status: "inactive",
    llm_config: %{api_key_env_var: "OPENAI_API_KEY", model: "gpt-4o"},
    abilities: ["Arboretum.Abilities.BatchQuery.handle/3"],
    responsibilities: ["batch_query:standard"],
    prompts: %{default: "You are a helpful assistant."},
    retry_policy: %{type: "fixed", max_retries: 3, delay_ms: 5000}
  }
  
  {:ok, batch} = Arboretum.BatchManager.create_agent_batch(base_config, 100)
  ```
  """
  @spec create_agent_batch(map(), pos_integer(), String.t()) :: 
    {:ok, %{batch_id: String.t(), agent_ids: [String.t()]}} | {:error, any()}
  def create_agent_batch(base_config, count \\ 100, batch_id \\ nil) do
    batch_id = batch_id || "batch-#{UUID.uuid4()}"
    Logger.info("Creating agent batch #{batch_id} with #{count} agents")
    
    # Create agents sequentially (in a production system, consider batching)
    agent_results = 
      Enum.map(0..(count-1), fn index ->
        # Create unique name for this agent
        agent_name = "#{base_config[:name] || "agent"}-#{batch_id}-#{index}"
        
        # Create agent with modified config
        agent_config = 
          base_config
          |> Map.put(:name, agent_name)
          |> Map.put(:status, "inactive") # Start as inactive for safety
        
        case Agents.create_agent(agent_config) do
          {:ok, agent} -> {:ok, agent.id}
          {:error, reason} -> {:error, {index, reason}}
        end
      end)
    
    # Check for errors
    errors = Enum.filter(agent_results, fn result -> match?({:error, _}, result) end)
    
    if Enum.empty?(errors) do
      # All agents created successfully
      agent_ids = Enum.map(agent_results, fn {:ok, id} -> id end)
      {:ok, %{batch_id: batch_id, agent_ids: agent_ids}}
    else
      # Some agents failed to create
      {:error, %{batch_id: batch_id, errors: errors}}
    end
  end
  
  @doc """
  Activates all agents in a batch.
  
  ## Parameters
  
  - `agent_ids` - List of agent IDs to activate
  
  ## Returns
  
  - `{:ok, %{successful: count, failed: count}}` - Status of activation
  - `{:error, reason}` - Error
  """
  @spec activate_agent_batch([String.t()]) :: 
    {:ok, %{successful: non_neg_integer(), failed: non_neg_integer()}} | {:error, any()}
  def activate_agent_batch(agent_ids) when is_list(agent_ids) do
    Logger.info("Activating #{length(agent_ids)} agents")
    
    results = 
      Enum.map(agent_ids, fn agent_id ->
        case Agents.change_agent_status(agent_id, "active") do
          {:ok, _} -> :ok
          error -> {:error, {agent_id, error}}
        end
      end)
    
    successful = Enum.count(results, fn result -> result == :ok end)
    failed = length(agent_ids) - successful
    
    {:ok, %{successful: successful, failed: failed}}
  end
  
  @doc """
  Triggers a specific responsibility on all agents in a batch.
  
  ## Parameters
  
  - `agent_ids` - List of agent IDs
  - `responsibility_key` - The responsibility key to trigger
  - `payload` - Payload to send (will be customized for each agent)
  
  ## Returns
  
  - `{:ok, %{successful: count, failed: count}}` - Status of triggers
  - `{:error, reason}` - Error
  """
  @spec trigger_batch_responsibility([String.t()], String.t(), map()) :: 
    {:ok, %{successful: non_neg_integer(), failed: non_neg_integer(), rate_limited: non_neg_integer()}} | {:error, any()}
  def trigger_batch_responsibility(agent_ids, responsibility_key, payload \\ %{}) do
    Logger.info("Triggering #{responsibility_key} on #{length(agent_ids)} agents")
    
    # Add rate limiting parameters to payload if not present
    payload = Map.put_new(payload, :rate_limiting, %{
      enabled: true,
      max_wait_ms: 60_000,  # Default to 1 minute max wait
      backoff_factor: 1.5   # Default backoff factor
    })
    
    # Setup counters for tracking results
    results = 
      agent_ids
      |> Enum.with_index()
      |> Enum.map(fn {agent_id, index} ->
        # Get the agent to determine rate limiting bucket
        agent = Agents.get_agent(agent_id)
        rate_limit_bucket = get_rate_limit_bucket_for_agent(agent)
        
        # Create a custom payload for this agent
        agent_payload = Map.merge(payload, %{agent_index: index})
        
        # Apply rate limiting if enabled
        rate_limiting_result =
          if get_in(agent_payload, [:rate_limiting, :enabled]) do
            # Use batch_id or responsibility_key as the key
            key = 
              case Map.get(payload, :batch_id) do
                nil -> responsibility_key
                batch_id -> batch_id
              end
            
            # Wait for rate limiting to allow this request
            wait_for_rate_limit(
              rate_limit_bucket,
              key,
              1,  # Default cost
              get_in(agent_payload, [:rate_limiting, :max_wait_ms]),
              get_in(agent_payload, [:rate_limiting, :backoff_factor])
            )
          else
            :ok  # Rate limiting disabled
          end
        
        # Check if rate limiting allowed this request
        case rate_limiting_result do
          :ok ->
            # Get the Registry name for this agent
            name_for_registry = {:via, Registry, {Arboretum.AgentRegistry, agent_id}}
            
            # Trigger the responsibility
            try do
              case GenServer.call(name_for_registry, {:trigger_responsibility, responsibility_key, agent_payload}) do
                {:ok, _result} -> :ok
                {:error, reason} -> {:error, {agent_id, reason}}
              end
            rescue
              e -> {:error, {agent_id, e}}
            catch
              :exit, reason -> {:error, {agent_id, {:exit, reason}}}
            end
          
          {:error, :max_wait_exceeded} ->
            {:rate_limited, agent_id}
        end
      end)
    
    successful = Enum.count(results, fn result -> result == :ok end)
    rate_limited = Enum.count(results, fn 
      {:rate_limited, _} -> true
      _ -> false
    end)
    failed = length(agent_ids) - successful - rate_limited
    
    {:ok, %{successful: successful, failed: failed, rate_limited: rate_limited}}
  end
  
  @doc """
  Deactivates all agents in a batch.
  
  ## Parameters
  
  - `agent_ids` - List of agent IDs to deactivate
  
  ## Returns
  
  - `{:ok, %{successful: count, failed: count}}` - Status of deactivation
  - `{:error, reason}` - Error
  """
  @spec deactivate_agent_batch([String.t()]) :: 
    {:ok, %{successful: non_neg_integer(), failed: non_neg_integer()}} | {:error, any()}
  def deactivate_agent_batch(agent_ids) when is_list(agent_ids) do
    Logger.info("Deactivating #{length(agent_ids)} agents")
    
    results = 
      Enum.map(agent_ids, fn agent_id ->
        case Agents.change_agent_status(agent_id, "inactive") do
          {:ok, _} -> :ok
          error -> {:error, {agent_id, error}}
        end
      end)
    
    successful = Enum.count(results, fn result -> result == :ok end)
    failed = length(agent_ids) - successful
    
    {:ok, %{successful: successful, failed: failed}}
  end
  
  @doc """
  Deletes all agents in a batch.
  
  ## Parameters
  
  - `agent_ids` - List of agent IDs to delete
  
  ## Returns
  
  - `{:ok, %{successful: count, failed: count}}` - Status of deletion
  - `{:error, reason}` - Error
  """
  @spec delete_agent_batch([String.t()]) :: 
    {:ok, %{successful: non_neg_integer(), failed: non_neg_integer()}} | {:error, any()}
  def delete_agent_batch(agent_ids) when is_list(agent_ids) do
    Logger.info("Deleting #{length(agent_ids)} agents")
    
    results = 
      Enum.map(agent_ids, fn agent_id ->
        case Agents.get_agent(agent_id) do
          %Agent{} = agent ->
            case Agents.delete_agent(agent) do
              {:ok, _} -> :ok
              error -> {:error, {agent_id, error}}
            end
          nil ->
            {:error, {agent_id, :not_found}}
        end
      end)
    
    successful = Enum.count(results, fn result -> result == :ok end)
    failed = length(agent_ids) - successful
    
    {:ok, %{successful: successful, failed: failed}}
  end
  
  #
  # Rate limiting functions
  #
  
  @doc """
  Checks if the request should be rate limited based on the requested bucket.
  
  ## Parameters
  
  - `bucket` - The rate limiting bucket to use (e.g., :default, :openai, "gpt-4")
  - `key` - The key to use for rate limiting (e.g., agent_id, batch_id)
  - `cost` - The cost of this request (default: 1)
  
  ## Returns
  
  - `:ok` - Request is allowed
  - `{:error, :rate_limited, ms_to_wait}` - Request is rate limited
  
  ## Examples
  
  ```elixir
  case check_rate_limit(:openai, agent_id) do
    :ok -> # proceed with the request
    {:error, :rate_limited, ms} -> # wait and retry
  end
  ```
  """
  @spec check_rate_limit(atom() | String.t(), String.t(), pos_integer()) :: 
    :ok | {:error, :rate_limited, pos_integer()}
  def check_rate_limit(bucket, _key, cost \\ 1) do
    # Get the bucket configuration
    {interval_ms, limit} = 
      case Map.get(@rate_limit_buckets, bucket) do
        nil -> @rate_limit_buckets.default
        bucket_config -> bucket_config
      end
    
    # Check if the request is allowed
    # Note: ExRated doesn't support a cost parameter, so we check multiple times for cost > 1
    check_result = 
      if cost == 1 do
        ExRated.check_rate(bucket, interval_ms, limit)
      else
        # For cost > 1, we need to check multiple times
        Enum.reduce_while(1..cost, {:ok, 0}, fn _i, _acc ->
          case ExRated.check_rate(bucket, interval_ms, limit) do
            {:ok, count} -> {:cont, {:ok, count}}
            {:error, _} = error -> {:halt, error}
          end
        end)
      end
    
    case check_result do
      {:ok, _count} -> :ok
      {:error, _limit} -> 
        # Calculate time to wait until next slot is available
        # This is an approximation - the exact time depends on the implementation
        # of ExRated and when previous requests were made
        ms_per_request = interval_ms / limit
        wait_time = ceil(ms_per_request * cost)
        
        {:error, :rate_limited, wait_time}
    end
  end
  
  @doc """
  Waits for a rate limited request to be allowed.
  
  ## Parameters
  
  - `bucket` - The rate limiting bucket to use
  - `key` - The key to use for rate limiting
  - `cost` - The cost of this request (default: 1)
  - `max_wait_ms` - Maximum time to wait in milliseconds (default: 30000)
  - `backoff_factor` - Factor to increase wait time for each retry (default: 1.5)
  
  ## Returns
  
  - `:ok` - Request is allowed
  - `{:error, :max_wait_exceeded}` - Waited too long
  
  ## Examples
  
  ```elixir
  case wait_for_rate_limit(:openai, agent_id) do
    :ok -> # proceed with the request
    {:error, :max_wait_exceeded} -> # handle error
  end
  ```
  """
  @spec wait_for_rate_limit(atom() | String.t(), String.t(), pos_integer(), pos_integer(), float()) ::
    :ok | {:error, :max_wait_exceeded}
  def wait_for_rate_limit(bucket, key, cost \\ 1, max_wait_ms \\ 30_000, backoff_factor \\ 1.5) do
    wait_for_rate_limit(bucket, key, cost, max_wait_ms, 0, backoff_factor)
  end
  
  # Internal implementation with accumulated wait time
  defp wait_for_rate_limit(_bucket, _key, _cost, max_wait_ms, acc_wait_ms, _backoff_factor) 
    when acc_wait_ms >= max_wait_ms do
    {:error, :max_wait_exceeded}
  end
  
  defp wait_for_rate_limit(bucket, key, cost, max_wait_ms, acc_wait_ms, backoff_factor) do
    case check_rate_limit(bucket, key, cost) do
      :ok -> :ok
      {:error, :rate_limited, wait_ms} ->
        # Apply backoff factor and ensure we don't exceed max wait
        adjusted_wait = min(wait_ms, max_wait_ms - acc_wait_ms)
        
        # Only wait if we have time left
        if adjusted_wait > 0 do
          Process.sleep(adjusted_wait)
          wait_for_rate_limit(bucket, key, cost, max_wait_ms, 
            acc_wait_ms + adjusted_wait, backoff_factor * wait_ms)
        else
          {:error, :max_wait_exceeded}
        end
    end
  end
  
  @doc """
  Determines the appropriate rate limit bucket for an agent based on its LLM configuration.
  
  ## Parameters
  
  - `agent` - The agent to check
  
  ## Returns
  
  - `atom() | String.t()` - The rate limit bucket to use (e.g., :openai, "gpt-4")
  
  ## Examples
  
  ```elixir
  bucket = get_rate_limit_bucket_for_agent(agent)
  ```
  """
  @spec get_rate_limit_bucket_for_agent(Agent.t() | nil) :: atom() | String.t()
  def get_rate_limit_bucket_for_agent(nil), do: :default
  def get_rate_limit_bucket_for_agent(%Agent{} = agent) do
    # Get the LLM config
    llm_config = agent.llm_config || %{}
    
    # Check if there's a model-specific rate limit
    model = Map.get(llm_config, "model")
    if model && Map.has_key?(@rate_limit_buckets, model) do
      model
    else
      # Determine the provider
      provider = 
        cond do
          # Check for explicit provider in config
          Map.get(llm_config, "provider") ->
            String.to_existing_atom(Map.get(llm_config, "provider"))
          
          # Infer from model name if available
          model && is_binary(model) ->
            cond do
              String.starts_with?(model, "gpt-") -> :openai
              String.starts_with?(model, "claude-") -> :anthropic
              String.starts_with?(model, "simulated-") -> :simulated
              true -> :default
            end
            
          # Default fallback
          true -> :default
        end
      
      # Check if there's a provider-specific bucket
      if Map.has_key?(@rate_limit_buckets, provider) do
        provider
      else
        :default
      end
    end
  rescue
    # Handle any errors (e.g., String.to_existing_atom fails)
    _ -> :default
  end
end