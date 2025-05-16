defmodule Arboretum.Abilities.BatchQuery do
  @moduledoc """
  An ability that supports batch processing of LLM queries.
  
  This ability is designed to work with the 100-agent concurrency milestone,
  allowing each agent to query an LLM with the same prompt and store the result
  in the database for analysis.
  
  ## Error Handling
  
  The ability implements comprehensive error handling:
  
  - Input validation for required parameters
  - LLM query timeouts and retries
  - Graceful handling of LLM API failures
  - Response validation to ensure quality
  - Persistent storage of results with metadata
  """
  
  use Arboretum.Abilities.Ability
  require Logger
  
  @timeout_ms 30_000  # 30 second timeout for LLM requests
  @max_retries 2      # Maximum number of retries for failed LLM requests
  
  @doc """
  Handle a batch query request.
  
  ## Parameters
  
  - `payload` - Map containing:
    - `:prompt` - The prompt to send to the LLM
    - `:batch_id` - Identifier for the batch operation
    - `:agent_index` - Index of this agent in the batch
    - `:timeout_ms` - Optional custom timeout
    - `:max_retries` - Optional custom retry count
    - `:metadata` - Optional metadata to store with the result
  
  - `agent_config` - The Agent configuration
  
  - `llm_client` - The LLM client to use for queries
  
  ## Returns
  
  - `{:ok, result}` - Successfully processed and stored result
  - `{:error, reason}` - Failed to process or store result
  """
  @impl true
  def handle(payload, agent_config, llm_client) do
    # Extract and validate parameters
    with {:ok, validated_params} <- validate_params(payload, agent_config),
         {:ok, llm_response} <- query_llm_with_retry(validated_params, llm_client),
         {:ok, result} <- process_response(llm_response, validated_params),
         {:ok, stored_result} <- store_result(result) do
      
      # Return success with the stored result
      {:ok, stored_result}
    else
      {:error, stage, reason, details} ->
        # Log detailed error with context
        Logger.error("BatchQuery failed at #{stage} stage: #{reason}, details: #{inspect(details)}")
        
        # Store the error in the database for tracking
        _ = store_error_result(stage, reason, details, payload, agent_config)
        
        # Return simplified error
        {:error, "#{stage} error: #{reason}"}
        
      {:error, reason} ->
        # Handle simple error format
        Logger.error("BatchQuery failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  # Validation
  
  defp validate_params(payload, agent_config) do
    # Extract parameters with defaults
    prompt = Map.get(payload, :prompt)
    batch_id = Map.get(payload, :batch_id)
    agent_index = Map.get(payload, :agent_index, 0)
    timeout_ms = Map.get(payload, :timeout_ms, @timeout_ms)
    max_retries = Map.get(payload, :max_retries, @max_retries)
    metadata = Map.get(payload, :metadata, %{})
    
    # Validate required parameters
    cond do
      is_nil(prompt) or prompt == "" ->
        {:error, :validation, "Missing prompt", payload}
        
      is_nil(batch_id) or batch_id == "" ->
        {:error, :validation, "Missing batch_id", payload}
        
      is_nil(agent_config) ->
        {:error, :validation, "Invalid agent configuration", agent_config}
        
      true ->
        # Return validated parameters
        {:ok, %{
          prompt: prompt,
          batch_id: batch_id,
          agent_id: agent_config.id,
          agent_name: agent_config.name,
          agent_index: agent_index,
          timeout_ms: timeout_ms,
          max_retries: max_retries,
          metadata: metadata
        }}
    end
  end
  
  # LLM Query with Retry
  
  defp query_llm_with_retry(params, llm_client, attempt \\ 0) do
    if attempt <= params.max_retries do
      try do
        # Log the attempt
        if attempt > 0 do
          Logger.info("Retrying LLM query (attempt #{attempt + 1}/#{params.max_retries + 1}) for batch #{params.batch_id}, agent #{params.agent_name}")
        else
          Logger.info("Executing LLM query for batch #{params.batch_id}, agent #{params.agent_name} (index: #{params.agent_index})")
        end
        
        # Apply timeout to the query
        task = Task.async(fn -> Arboretum.LLMClient.query(llm_client, params.prompt) end)
        
        case Task.yield(task, params.timeout_ms) || Task.shutdown(task) do
          {:ok, {:ok, response}} ->
            # Extract text from response
            case Arboretum.LLMClient.extract_text({:ok, response}) do
              {:ok, text} when is_binary(text) and text != "" ->
                {:ok, text}
                
              {:ok, ""} ->
                # Empty response, retry
                Logger.warning("Empty response from LLM for batch #{params.batch_id}, agent #{params.agent_name}")
                query_llm_with_retry(params, llm_client, attempt + 1)
                
              {:error, reason} ->
                {:error, :response_extraction, "Failed to extract text", reason}
            end
            
          {:ok, {:error, reason}} ->
            # LLM API error, retry if possible
            if attempt < params.max_retries do
              # Exponential backoff: 1s, 2s, 4s, etc.
              backoff_ms = :math.pow(2, attempt) * 1000 |> round()
              :timer.sleep(backoff_ms)
              query_llm_with_retry(params, llm_client, attempt + 1)
            else
              {:error, :llm_query, "LLM error after retries", reason}
            end
            
          nil ->
            # Timeout occurred
            Logger.warning("LLM query timeout for batch #{params.batch_id}, agent #{params.agent_name}")
            
            if attempt < params.max_retries do
              query_llm_with_retry(params, llm_client, attempt + 1)
            else
              {:error, :timeout, "LLM query timed out after retries", %{timeout_ms: params.timeout_ms}}
            end
        end
      rescue
        e ->
          # Unexpected error
          Logger.error("Exception in LLM query: #{inspect(e)}")
          {:error, :exception, "Exception during LLM query", e}
      end
    else
      {:error, :max_retries, "Exceeded maximum retry attempts", %{max_retries: params.max_retries}}
    end
  end
  
  # Process Response
  
  defp process_response(text, params) do
    # Basic response validation
    cond do
      String.length(text) < 10 ->
        {:error, :validation, "Response too short", text}
        
      String.length(text) > 100_000 ->
        {:error, :validation, "Response too long", %{length: String.length(text)}}
        
      true ->
        # Create result record with metadata
        result = %{
          batch_id: params.batch_id,
          agent_id: params.agent_id,
          agent_name: params.agent_name,
          agent_index: params.agent_index,
          prompt: params.prompt,
          response: text,
          metadata: params.metadata
        }
        
        {:ok, result}
    end
  end
  
  # Database Storage
  
  defp store_result(result) do
    case Arboretum.BatchResults.store_result(result) do
      {:ok, stored_result} ->
        # Log success with preview
        preview = String.slice(result.response, 0, 50)
        Logger.info("Stored result for batch #{result.batch_id}, agent #{result.agent_name}: #{preview}...")
        {:ok, stored_result}
        
      {:error, changeset} ->
        {:error, :storage, "Failed to store result", changeset}
    end
  end
  
  defp store_error_result(stage, reason, details, payload, agent_config) do
    # Create an error record to track failures
    error_result = %{
      batch_id: Map.get(payload, :batch_id, "unknown_batch"),
      agent_id: agent_config.id,
      agent_name: agent_config.name,
      agent_index: Map.get(payload, :agent_index, 0),
      prompt: Map.get(payload, :prompt, ""),
      response: "ERROR: #{stage} - #{reason}",
      metadata: %{
        error: true,
        error_stage: stage,
        error_reason: reason,
        error_details: details
      }
    }
    
    # Store the error
    case Arboretum.BatchResults.store_result(error_result) do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  end
end