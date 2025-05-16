defmodule Arboretum.Abilities.QueryLLM do
  @moduledoc """
  An ability that queries the LLM with a prompt.
  
  This ability demonstrates how to use the LLM client to make queries to a language model.
  """
  
  use Arboretum.Abilities.Ability
  require Logger
  
  @impl true
  def handle(payload, agent_config, llm_client) do
    prompt = 
      case payload do
        %{prompt: p} when is_binary(p) -> p
        p when is_binary(p) -> p
        _ -> "No valid prompt provided"
      end
      
    Logger.info("QueryLLM ability called for agent #{agent_config.name} with prompt: #{prompt}")
    
    # Use a task prompt from the agent's configuration if available
    task_type = Map.get(payload, :task_type, "default")
    prompt_template = get_prompt_template(agent_config, task_type)
    
    final_prompt = if prompt_template do
      String.replace(prompt_template, "{prompt}", prompt)
    else
      prompt
    end
    
    # Query the LLM
    case Arboretum.LLMClient.query(llm_client, final_prompt) do
      {:ok, response} ->
        # Extract the text from the response
        case Arboretum.LLMClient.extract_text(response) do
          {:ok, text} ->
            result = %{
              prompt: prompt,
              response: text,
              timestamp: DateTime.utc_now()
            }
            {:ok, result}
            
          {:error, reason} ->
            Logger.error("Failed to extract text from LLM response: #{inspect(reason)}")
            {:error, "Failed to extract text from LLM response: #{inspect(reason)}"}
        end
        
      {:error, reason} ->
        Logger.error("LLM query failed: #{inspect(reason)}")
        {:error, "LLM query failed: #{inspect(reason)}"}
    end
  end
  
  # Get the prompt template for a specific task type
  defp get_prompt_template(agent_config, task_type) do
    prompts = agent_config.prompts || %{}
    Map.get(prompts, task_type) || Map.get(prompts, "default")
  end
end