defmodule ArboretumWeb.BatchLive.New do
  use ArboretumWeb, :live_view

  alias Arboretum.BatchManager
  alias Arboretum.Agents
  alias Phoenix.HTML.Form
  
  @impl true
  def mount(_params, _session, socket) do
    providers = [
      {"OpenAI", "openai"},
      {"Anthropic", "anthropic"},
      {"Simulated (Testing)", "simulated"}
    ]
    
    models = %{
      "openai" => [{"GPT-4o (Recommended)", "gpt-4o"}, {"GPT-4", "gpt-4"}],
      "anthropic" => [{"Claude-3 Opus", "claude-3-opus-20240229"}, {"Claude-3 Sonnet", "claude-3-sonnet-20240229"}],
      "simulated" => [{"Simulated Model", "simulated-model"}]
    }
    
    {:ok, assign(socket, 
      page_title: "New Batch Operation",
      providers: providers,
      models: models,
      form: to_form(%{
        "provider" => "simulated",
        "model" => "simulated-model",
        "count" => 10,
        "prompt" => "What is the meaning of life?",
        "batch_id" => "batch-#{random_string(8)}",
        "rate_limiting" => true,
        "max_wait_ms" => 60000
      }),
      creating: false,
      result: nil,
      errors: []
    )}
  end
  
  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
  
  @impl true 
  def handle_event("validate", %{"form" => form_params}, socket) do
    # Simple validation
    errors = validate_form(form_params)
    
    {:noreply, assign(socket, 
      form: to_form(form_params),
      errors: errors
    )}
  end
  
  @impl true
  def handle_event("create_batch", %{"form" => form_params}, socket) do
    # Validate form
    errors = validate_form(form_params)
    
    if errors == [] do
      # Start creation process
      {:noreply, assign(socket, 
        creating: true, 
        form: to_form(form_params),
        errors: []
      )}
    else
      {:noreply, assign(socket, 
        form: to_form(form_params),
        errors: errors
      )}
    end
  end
  
  @impl true
  def handle_info(:create_batch, socket) do
    form_params = socket.assigns.form.params
    
    # Create batch operation
    result = create_batch(form_params)
    
    {:noreply, assign(socket, 
      creating: false,
      result: result
    )}
  end
  
  # Helper to perform the actual batch creation
  defp create_batch(params) do
    try do
      # Extract params
      provider = params["provider"]
      model = params["model"]
      count = String.to_integer(params["count"])
      prompt = params["prompt"]
      batch_id = params["batch_id"]
      
      rate_limiting = 
        case params["rate_limiting"] do
          "true" -> true
          true -> true
          _ -> false
        end
        
      max_wait_ms = 
        case params["max_wait_ms"] do
          ms when is_binary(ms) -> String.to_integer(ms)
          ms when is_integer(ms) -> ms
          _ -> 60000
        end
      
      # Create base agent config
      base_config = %{
        name: "batch-agent",
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
      
      # Create agents
      with {:ok, %{batch_id: ^batch_id, agent_ids: agent_ids}} <- 
            BatchManager.create_agent_batch(base_config, count, batch_id),
            
            # Activate the agents
            {:ok, _activation_result} <- BatchManager.activate_agent_batch(agent_ids),
            
            # Trigger the batch query with rate limiting
            {:ok, trigger_result} <- BatchManager.trigger_batch_responsibility(
              agent_ids,
              "batch_query:standard",
              %{
                batch_id: batch_id,
                prompt: prompt,
                rate_limiting: %{
                  enabled: rate_limiting,
                  max_wait_ms: max_wait_ms,
                  backoff_factor: 1.5
                }
              }
            ) do
              
        # Return success with results  
        {:ok, %{
          batch_id: batch_id,
          agent_count: count,
          successful: trigger_result.successful,
          failed: trigger_result.failed,
          rate_limited: trigger_result.rate_limited
        }}
      else
        {:error, reason} -> {:error, reason}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end
  
  # Form validation
  defp validate_form(params) do
    errors = []
    
    # Validate count
    errors = 
      case params["count"] do
        count when is_binary(count) ->
          case Integer.parse(count) do
            {n, _} when n > 0 and n <= 500 -> errors
            {n, _} when n > 500 -> [{"count", "Maximum 500 agents allowed"} | errors]
            {n, _} when n <= 0 -> [{"count", "Must be greater than 0"} | errors]
            _ -> [{"count", "Must be a valid number"} | errors]
          end
        _ -> [{"count", "Must be a valid number"} | errors]
      end
    
    # Validate prompt
    errors =
      case params["prompt"] do
        prompt when is_binary(prompt) and byte_size(prompt) > 0 -> errors
        _ -> [{"prompt", "Prompt cannot be empty"} | errors]
      end
      
    # Validate batch_id
    errors =
      case params["batch_id"] do
        id when is_binary(id) and byte_size(id) > 0 -> errors
        _ -> [{"batch_id", "Batch ID cannot be empty"} | errors]
      end
      
    errors
  end
  
  # Helper to generate a random string for batch IDs
  defp random_string(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.encode16(case: :lower)
  end
  
  # Helper to get the environment variable name for API keys
  defp get_api_key_env_var(provider) do
    case provider do
      "openai" -> "OPENAI_API_KEY"
      "anthropic" -> "ANTHROPIC_API_KEY"
      _ -> nil
    end
  end
end